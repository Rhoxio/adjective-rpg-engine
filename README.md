# Adjective
## A utility that can be used to help ease the creation of RPG games

The intent of this project is to establish core functionality that is found in traditional JRPG games and allows you to extend them and modify initial values and pass in your own modifiers instead of having to write all of the more-or-less boilerplate interaction logic. 

The included functionality will have the ability to change multipliers, add conditions, and generally save time by modifying values as opposed to hard-coding values. This will make for quick customization and the ability to turn out encounters quickly so you can rapidly prototype and test new ideas.

It will include modules for usage such as:
 - Skills
 - Equipment
 - Inventory
 - Items
 - Effects (Buffs/Debuffs)
 - Experience
 - Actors (Characters)
 - Encounters
 - Locations

 It will also utilize ActiveRecord to handle relationships and data persistence, if you so choose.
 
### Ideation
#### Notes on how to implement and sync up the appropriate models to one another

##### Actor
This model will hold and control the values and transformations for itself. The top-level functionality set is as follows:
  Base Data:
   - Name
   - Level
   - EXP
   - Metadata (custom values)
  Related Data:
   - Inventory
   - Skills
   - Equipment
   - Effects
   - Locations
