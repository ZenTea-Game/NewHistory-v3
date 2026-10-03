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

  // Спусковой механизм добавляем только если предмет и все компоненты
  // зарегистрированы в текущей сборке сервера.
  const trigger = 'createimmersivetacz:gun_trigger';
  const triggerParts = [
    'minecraft:iron_nugget',
    'create:iron_sheet',
    'minecraft:redstone',
    'kubejs:resine_sheet'
  ];
  if (Item.exists(trigger) && triggerParts.every(id => Item.exists(id))) {
    event.shaped(trigger, [
      ' N ',
      'SRS',
      ' P '
    ], {
      N: 'minecraft:iron_nugget',
      S: 'create:iron_sheet',
      R: 'minecraft:redstone',
      P: 'kubejs:resine_sheet'
    }).id('newhistory:createimmersivetacz_gun_trigger');
  }

  // Рецепт каши больше не зависит от отсутствующего Immersive Engineering.
  if (Item.exists('kubejs:zero_food')) {
    event.remove({ output: 'kubejs:zero_food' });
    event.shapeless('kubejs:zero_food', [
      'minecraft:bowl',
      '#minecraft:planks'
    ]).id('newhistory:zero_food_from_bowl_and_plank');
  }
});
