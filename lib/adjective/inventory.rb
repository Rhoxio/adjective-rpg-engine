class Inventory
  attr_accessor :items, :grouped_items

  def initialize(items = []) 
    # Initially takes a set of all items as separate instances.
    # As long as it responds to #id, it should all work out fine.
    # @items = items
    @items = items
    @grouped_items = group_items(items)
  end

  def find_by_id(id)
    @grouped_items[id]
  end

  def sort
    return @items.sort_by { |item| item.id }
  end

  def sort_by(attribute)
    raise RuntimeError, "'#{attribute}' is not present on an item set: #{items}" if items.any? {|item| !item.respond_to?(attribute)} 
    return @items.sort_by { |item| item.send(attribute) }
  end

  def sort!
    @items = @items.sort_by { |item| item.id }
  end

  def sort_by!(attribute)
    raise RuntimeError, "'#{attribute}' is not present on an item set: #{items}" if items.any? {|item| !item.respond_to?(attribute)} 
    @items = @items.sort_by { |item| item.send(attribute) }
  end

  def sort_grouped_items_by(attribute)
    # This is meant to be a nested sort that takes the grouped_items and sorts them 
    # by a certain attribute. This attribute can be anything, as long as the 
    # code itself reponds to the method.
    raise RuntimeError, "'#{attribute}' is not present on an item set: #{items}" if items.any? {|item| !item.respond_to?(attribute)} 

  end

  private

  def group_items(items)
    return {} if items.length == 0 

    if (items.any? {|item| !item.respond_to?(:id)} || items.any? {|item| item.nil? })
      raise RuntimeError, "Given item is invalid. Ensure that the item has an id assigned and is not nil: #{items}" 
    end

    grouped_items = {}
    items.each do |item|
      if !grouped_items.key?(item.id)
        grouped_items[item.id] = [item]
      elsif grouped_items.key?(item.id)
        grouped_items[item.id] << item
      end
    end

    return grouped_items
  end

  # def sort_by(attribute)
  #   # Taken as a symbol...

  #   @items = @items
  # end

  # This system is meant to be able to take in arrays of items and return 
  # different imformation about the collection of objects. This may end up being primarily utility
  # methods to ease common uses for the inventory. 

  # I am going to assume that they are using a class to represent their items
  # and that it will either a) be the Item class from this work or
  # their own custom-defined attribute on a child class. 

  # 1. Needs to handle lists of ambiguous data and return sorted data.
  # 2. Needs to be able to filter lists of ambiguous data by attribute.
  # 3. Needs to be able to insert/pop/shift items.
  # 4. Needs to be able to increment/decrement/set number of Items.
  # 5. Needs to have flexibility for limited/unlimited slots.

end