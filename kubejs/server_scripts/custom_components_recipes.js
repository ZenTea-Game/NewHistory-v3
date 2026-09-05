// kubejs/server_scripts/custom_components_recipes.js

ServerEvents.recipes(event => {

  // 1. Превращаем Железную пластину (IE) в Железный лист (Create)
  // Используем бесформенный крафт: просто положите пластину в верстак
  event.shapeless('create:iron_sheet', ['immersiveengineering:plate_iron']).id('kubejs:ie_plate_to_create_sheet');

  // 2. Превращаем Железный лист (Create) в Железную пластину (IE)
  // Возвращаем 1 пластину за 2 листа (баланс, так как листы обычно дешевле/проще)
  // Или 1 к 1, если хотите прямой обмен. Ниже вариант 2 листа -> 1 пластина.
  event.shapeless('immersiveengineering:plate_iron', ['create:iron_sheet' ]).id('kubejs:create_sheet_to_ie_plate');

  // ===== 2. ГЛОБАЛЬНЫЕ ЗАМЕНЫ =====
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
  
  // ===== 3. СПУСКОВОЙ КРЮЧОК =====
  event.shaped('createimmersivetacz:gun_trigger', [
    ' N ',
    'SRS',
    ' P '
  ], {
    N: 'minecraft:iron_nugget',
    S: 'create:iron_sheet',
    R: 'minecraft:redstone',
    P: 'kubejs:resine_sheet'
  });

  event.shaped('kubejs:zero_food', [
    'SSS',
    'SSS',
    ' N '
  ], {
    N: 'minecraft:bowl',
    S: 'immersiveengineering:dust_wood',
  });


});