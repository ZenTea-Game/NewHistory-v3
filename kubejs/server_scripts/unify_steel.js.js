// unify_all_materials.js
// Унификация стальных слитков и всех листов (пластин) из разных модов

ServerEvents.tags('item', event => {
    // ========== СТАЛЬНЫЕ СЛИТКИ ==========
    event.add('forge:ingots/steel', [
        'createnuclear:steel_ingot',          // Create Nuclear
        'samurai_dynasty:steel_ingot',        // Samurai Dynasty
        'immersiveengineering:ingot_steel',   // Immersive Engineering
        'createbigcannons:steel_ingot',       // Create Big Cannons
        'tfmg:steel_ingot'                    // Create: The Factory Must Grow
    ]);

    // ========== ЛИСТЫ (ПЛАСТИНЫ) ПО МАТЕРИАЛАМ ==========
    // Медь
    event.add('forge:sheets/copper', [
        'create:copper_sheet',
        'immersiveengineering:plate_copper'
    ]);

    // Железо
    event.add('forge:sheets/iron', [
        'create:iron_sheet',
        'immersiveengineering:plate_iron'
    ]);

    // Золото
    event.add('forge:sheets/gold', [
        'create:golden_sheet',
        'immersiveengineering:plate_gold'
    ]);

    // Латунь
    event.add('forge:sheets/brass', [
        'create:brass_sheet'
    ]);

    // Цинк
    event.add('forge:sheets/zinc', [
        'createaddition:zinc_sheet'
    ]);

    // Алюминий
    event.add('forge:sheets/aluminum', [
        'tfmg:aluminum_sheet',
        'immersiveengineering:plate_aluminum'
    ]);

    // Никель
    event.add('forge:sheets/nickel', [
        'tfmg:nickel_sheet',
        'immersiveengineering:plate_nickel'
    ]);

    // Свинец
    event.add('forge:sheets/lead', [
        'tfmg:lead_sheet',
        'immersiveengineering:plate_lead'
    ]);

    // Платина
    event.add('forge:sheets/platinum', [
        'createpropulsion:platinum_sheet'
    ]);

    // Электрум
    event.add('forge:sheets/electrum', [
        'createaddition:electrum_sheet',
        'immersiveengineering:plate_electrum'
    ]);

    // Константан
    event.add('forge:sheets/constantan', [
        'immersiveengineering:plate_constantan'
    ]);

    // Сталь (лист)
    event.add('forge:sheets/steel', [
        'immersiveengineering:plate_steel'
    ]);

    // Резина
    event.add('forge:sheets/rubber', [
        'tfmg:rubber_sheet'
    ]);

    // Пластик
    event.add('forge:sheets/plastic', [
        'tfmg:plastic_sheet'
    ]);

    // Чугун
    event.add('forge:sheets/cast_iron', [
        'tfmg:cast_iron_sheet'
    ]);

    // Магнитный сплав
    event.add('forge:sheets/magnetic_alloy', [
        'tfmg:magnetic_alloy_sheet'
    ]);

    // Серебро
    event.add('forge:sheets/silver', [
        'immersiveengineering:plate_silver'
    ]);

    // Уран (если нужен)
    event.add('forge:sheets/uranium', [
        'immersiveengineering:plate_uranium'
    ]);
});

ServerEvents.recipes(event => {
    // ===== Удаляем рецепты стальных слитков, которые не должны существовать =====

    // 1. Create Nuclear: механический смеситель
    event.remove({
        output: 'createnuclear:steel_ingot',
        type: 'create:mixing'
    });

    // 2. Samurai Dynasty: плавильная печь (из железа)
    event.remove({
        output: 'samurai_dynasty:steel_ingot',
        type: 'minecraft:blasting'
    });

    // 3. Samurai Dynasty: вентилятор за лавой (обжиг)
    event.remove({
        output: 'samurai_dynasty:steel_ingot',
        type: 'create:fan_blasting'
    });

    // (Опционально) Если есть рецепт в обычной печи – тоже удаляем:
    // event.remove({ output: 'samurai_dynasty:steel_ingot', type: 'minecraft:smelting' });

    // ===== 1. Заменяем стальные слитки на общий тег =====
    const steelIngots = [
        'createnuclear:steel_ingot',
        'samurai_dynasty:steel_ingot',
        'immersiveengineering:ingot_steel',
        'createbigcannons:steel_ingot',
        'tfmg:steel_ingot'
    ];
    steelIngots.forEach(ingot => {
        event.replaceInput({}, ingot, '#forge:ingots/steel');
    });

    // ===== 2. Заменяем все листы на соответствующие теги =====
    const sheetReplacements = [
        // Медь
        ['create:copper_sheet', '#forge:sheets/copper'],
        ['immersiveengineering:plate_copper', '#forge:sheets/copper'],
        // Железо
        ['create:iron_sheet', '#forge:sheets/iron'],
        ['immersiveengineering:plate_iron', '#forge:sheets/iron'],
        // Золото
        ['create:golden_sheet', '#forge:sheets/gold'],
        ['immersiveengineering:plate_gold', '#forge:sheets/gold'],
        // Латунь
        ['create:brass_sheet', '#forge:sheets/brass'],
        // Цинк
        ['createaddition:zinc_sheet', '#forge:sheets/zinc'],
        // Алюминий
        ['tfmg:aluminum_sheet', '#forge:sheets/aluminum'],
        ['immersiveengineering:plate_aluminum', '#forge:sheets/aluminum'],
        // Никель
        ['tfmg:nickel_sheet', '#forge:sheets/nickel'],
        ['immersiveengineering:plate_nickel', '#forge:sheets/nickel'],
        // Свинец
        ['tfmg:lead_sheet', '#forge:sheets/lead'],
        ['immersiveengineering:plate_lead', '#forge:sheets/lead'],
        // Платина
        ['createpropulsion:platinum_sheet', '#forge:sheets/platinum'],
        // Электрум
        ['createaddition:electrum_sheet', '#forge:sheets/electrum'],
        ['immersiveengineering:plate_electrum', '#forge:sheets/electrum'],
        // Константан
        ['immersiveengineering:plate_constantan', '#forge:sheets/constantan'],
        // Сталь (лист)
        ['immersiveengineering:plate_steel', '#forge:sheets/steel'],
        // Резина
        ['tfmg:rubber_sheet', '#forge:sheets/rubber'],
        // Пластик
        ['tfmg:plastic_sheet', '#forge:sheets/plastic'],
        // Чугун
        ['tfmg:cast_iron_sheet', '#forge:sheets/cast_iron'],
        // Магнитный сплав
        ['tfmg:magnetic_alloy_sheet', '#forge:sheets/magnetic_alloy'],
        // Серебро
        ['immersiveengineering:plate_silver', '#forge:sheets/silver'],
        // Уран
        ['immersiveengineering:plate_uranium', '#forge:sheets/uranium']
    ];

    sheetReplacements.forEach(([item, tag]) => {
        event.replaceInput({}, item, tag);
    });
});