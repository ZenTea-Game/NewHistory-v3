// kubejs/server_scripts/custom_components_recipes.js
// Совместимо с серверами, где опциональные аддоны отсутствуют.

ServerEvents.recipes(event => {
  // Замены для Create: Immersive TaCZ применяются только к его рецептам.
  event.replaceInput(
    { mod: 'createimmersivetacz' },
    'minecraft:iron_ingot',
    'kubejs:metal_alloy'
  );
  event.replaceInput(
    { mod: 'createimmersivetacz' },
    'create:brass_block',
    'kubejs:brass_frame'
  );

  // Не добавляем верстачный обход рецепта спускового механизма:
  // у Create: Immersive TaCZ уже есть версия для Mechanical Crafter.

  // Рецепт каши больше не зависит от отсутствующего Immersive Engineering.
  if (Item.exists('kubejs:zero_food')) {
    event.remove({ output: 'kubejs:zero_food' });
    event.shapeless('kubejs:zero_food', [
      'minecraft:bowl',
      '#minecraft:planks'
    ]).id('newhistory:zero_food_from_bowl_and_plank');
  }
});
