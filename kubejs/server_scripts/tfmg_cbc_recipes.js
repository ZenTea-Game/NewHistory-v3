// TFMG / Create Big Cannons compatibility and recovered progression recipes.
// MaxZT + AI | NewHistory 6 | Minecraft 1.21.1 / NeoForge 21.1.236

ServerEvents.recipes(event => {
  // Restore CBC's original heated mixer recipe. The resource path is
  // data/createbigcannons/recipe/mixing/alloy_steel.json, so its actual ID
  // includes the "mixing/" segment.
  if (Item.exists('createbigcannons:steel_ingot')) {
    event.remove({ id: 'createbigcannons:mixing/alloy_steel' });
    event.custom({
      type: 'create:mixing',
      heat_requirement: 'heated',
      ingredients: [
        { tag: 'c:ingots/iron' },
        { tag: 'c:ingots/iron' },
        { tag: 'minecraft:coals' }
      ],
      results: [
        { id: 'createbigcannons:steel_ingot', count: 2 }
      ]
    }).id('createbigcannons:mixing/alloy_steel');
  }

  // Smelt crushed TFMG bauxite powder into aluminum in the furnace or blast furnace.
  if (Item.exists('tfmg:bauxite_powder') && Item.exists('tfmg:aluminum_ingot')) {
    event.remove({ id: 'newhistory:aluminum_from_bauxite_smelting' });
    event.remove({ id: 'newhistory:aluminum_from_bauxite_blasting' });
    event.smelting('tfmg:aluminum_ingot', 'tfmg:bauxite_powder')
      .xp(0.7)
      .cookingTime(200)
      .id('newhistory:aluminum_from_bauxite_smelting');
    event.blasting('tfmg:aluminum_ingot', 'tfmg:bauxite_powder')
      .xp(0.7)
      .cookingTime(100)
      .id('newhistory:aluminum_from_bauxite_blasting');
  }
});
