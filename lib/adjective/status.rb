module Adjective

  # Status is different from something like an attack in that it applies
  # to things that afflict the subject for one or more turns.

  module Status

    include Adjective::Temporable

    # Initialize module data for Status
    # @param opts [Hash]
    # @return [Object]
    # @example
    #   options = {affected_attributes: { hitpoints: 3}, max_duration: 5}
    #   class MyStatus
    #     include Adjective::Status
    #     def initialize(name, opts = {})
    #       @name = name
    #       initialize_status(opts)   
    #     end 
    #   end
    #   new_status = MyStatus.new("MyStatus", options)
    #   # Or something with a :static @tick_type...
    #   cripple = MyStatus.new("Cripple", {affected_attributes: { crit_multiplier: 1.0 }, max_duration: 5, tick_type: :static, reset_references: {crit_multiplier: :baseline_crit_multiplier} })
    #   # Or even something with a :compounding @tick_type
    #   decay = MyStatus.new("Decay", {affected_attributes: { hitpoints: -5 }, max_duration: 10, tick_type: :compounding, compounding_factor: Proc.new {|value, turn_mod| (value - turn_mod) * 1.5 }})
    def initialize_status(opts = {})
      attributes = opts[:affected_attributes] 
      @modifiers = attributes ||= {}
      @affected_attributes = attributes.map{|entry| entry[0]}

      @tick_type = opts[:tick_type] ||= :linear
      @compounding_factor = opts[:compounding_factor] ||= Proc.new { |value| value } 
      @reset_references = opts[:reset_references] ||= {}

      # @applied_at Can be used to track simple object intantation if class is created when status is applied.
      # TODO: If held in memory, opts will need to be given a :timestamp with a value comparable with a Time object. (Custom values should help?)
      # If the user wishes to sort by a specific attribute in Statusable, then they should pass a block and do so there. (Maybe?)
      @applied_at = opts[:timestamp] ||= Time.now

      [:initialized_at, :affected_attributes, :modifiers, :tick_type, :compounding_factor, :reset_references].each do |attribute| 
        self.class.send(:attr_reader, attribute)
      end
      
      initialize_temporality(opts)
      normalize_remaining_duration
      assign_affected_attributes
      return self
    end

    # Will perform tick functionality, whose default action is to reduce @remaining_duration (from Temporable) by 1.
    # Otherwise, it will accept a block and bypass all default functionality.
    # 
    # The default functionality depends on what +@tick_type+ the status itself has been assigned and defaults to +:linear+. 
    # 
    # Status.tick will always return a Hash with the keys being the +affected_attributes+ explicitly, and the value being the associated +value+. 
    # e.x. +{hitpoints: -6, gold: -1}+
    # 
    # NOTE: If you want it to work with the default functionality present in +Statusable#tick_all+ while foregoing the default +Status.tick+ functionality, 
    # you will need to have the given block in +Status#tick+ return a Hash with the proper symbolized key names and the corresponding values to be amended. 
    # e.x. +{hitpoints: -6, fear: 4}+ 
    # 
    # There are some key differences in processing for each +@tick_type+:
    # 
    # A +:linear+ +@tick_type+ on a status will apply '+=' to the +affected_attribute+. It is intended to work with numeric datatypes by default. 
    # 
    # A +:static+ +@tick_type+ will apply the status using +public_send("#{attribute}=", value)+ on the first turn and will remain until the remaining_duration 
    # reaches 0 or the status is removed with +Statusable#clear_expired_statuses!+ or +Statusable#remove_status(es)+. It is worth noting that the status will need to have a +@reset_references+ 
    # present for this to work by default. e.x. +@reset_references = {crit_multiplier: :baseline_crit_multiplier}+ if you modified @crit_multiplier and wanted it to automatically reset to whatever 
    # +self.send(:baseline_crit_modifier)+ returns after expiration. 
    # 
    # A +:compounding+ +@tick_type+ will give the provided +Proc+ set in +@compounding_factor+ and supply it with +turn_modifier+ (negative or positive depending on if the given value is < 0, but never 0) 
    # and the initial +value+ present on the modifier itself. You can do whatever you want to with this, and as long as it returns a float or integer, you have the power to amend the way the status compounds to your heart's content. 
    # @param status_proc [Proc]
    # @param block [Block]
    # @return [Object]
    # @example
    #   MyStatus.tick
    #   MyStatus.tick(Proc.new{|value, turn_mod| (value + turn_mod) ** 2})
    #   MyStatus.tick {|status| p "this can be anything and will override default functionality"}
    def tick(status_proc = nil, &block)
      if block_given?
        # This needs to be explicitly tested next.
        output = yield(self)
      else
        output = {}
        if tick_type == :compounding
          modifiers.each do |key, value| 
            turn_modifier = value < 0 ? (max_duration - remaining_duration) - 1 : (max_duration - remaining_duration) + 1
            initial_value = value < 0 ? (value - turn_modifier) : (value + turn_modifier)
            # Turn 1 exception is necessary (so far)
            compounded_value = max_duration == remaining_duration ? value : compounding_factor.call(initial_value, turn_modifier)
            output.store(key, compounded_value.round.to_i) 
          end
        elsif (tick_type == :static && (max_duration == remaining_duration)) || tick_type == :linear
          modifiers.each {|key, value| output.store(key, value) }  
        end
        @remaining_duration -= 1
        status_proc.call(self, output) if status_proc
      end
      return output
    end

    # Checks if the status has a modifier present
    # @return [Boolean]
    # @example
    #   MyStatus.has_modifier?(:hitpoints)
    def has_modifier?(attribute)
      @modifiers.key?(attribute)
    end

    # Adds or updates the modifier hash. 
    # @param attribute [Symbol]
    # @param value [Integer, Float, String]
    # @return [Hash]
    # @example
    #   MyStatus.add_or_update_modifer(:hitpoints, 10)
    def add_or_update_modifier(attribute, value)
      if has_modifier?(attribute)
        @modifiers[attribute] = value
      else
        @modifiers.store(attribute, value)
      end
      assign_affected_attributes
      return @modifiers
    end

    # Updates the modifier in @modifiers. Will warn and NOT amend if modifier does not exist.
    # @param attribute [Symbol]
    # @param value [Integer, Float, String]
    # @return [Hash]
    # @example
    #   MyStatus.update_modifier(:hitpoints, 12)
    def update_modifier(attribute, value)
      if has_modifier?(attribute)
        @modifiers[attribute] = value
        assign_affected_attributes
      else
        warn("[#{Time.now}]: Attempted to update a modifier that wasn't present: #{attribute}. Use #add_modifier or #add_or_update_modifier instead.")
      end
      return @modifiers
    end

    # Adds to the modifier to @modifiers. Will warn and NOT amend if modifier already exists.
    # @param attribute [Symbol]
    # @param value [Integer, Float, String]
    # @return [Hash]
    # @example
    #   MyStatus.add_modifer(:strength, 20)
    def add_modifier(attribute, value)
      if !has_modifier?(attribute)
        @modifiers.store(attribute, value)
        assign_affected_attributes
      else
        warn("[#{Time.now}]: Attempted to add duplicate modifier: #{attribute}. The new value has NOT been set. (Currently '#{@modifiers[attribute]}').")
      end
      return @modifiers
    end 

    # Removes the specified modifier from @modifers. 
    # @param attribute [Symbol]
    # @param value [Integer, Float, String]
    # @return [Hash]
    # @example
    #   MyStatus.add_modifer(:strength, 20)
    def remove_modifier(attribute)
      if has_modifier?(attribute)
        temp = {}.store(attribute, modifiers[attribute])
        @modifiers.delete(attribute)
      else
        warn("[#{Time.now}]: Attempted to remove modifier that does not exist: #{attribute}")
      end
      return temp
    end

    private

    # Converts the modifier hash into a digestable array for other modules to use. Includes '@' in modifier value,
    # as the format for the metaprogramming in other modules requires the attribute to be called and set explicitly if not publicly writable.
    # This should most likely be left alone and not called outside of the implementation here.
    # @private
    # @return [Hash]
    def assign_affected_attributes
      @affected_attributes.map!{|attribute| ("@"+attribute.to_s).to_sym }
    end

  end
end