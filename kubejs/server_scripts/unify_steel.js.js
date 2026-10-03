// Сведение стали и листов к тегам только из установленных модов.
// Samurai Dynasty и Immersive Engineering в этой сборке отсутствуют.

ServerEvents.tags('item', event => {
    event.add('forge:ingots/steel', [
        'createnuclear:steel_ingot',
        'createbigcannons:steel_ingot',
        'tfmg:steel_ingot'
    ]);

    event.add('forge:sheets/copper', ['create:copper_sheet']);
    event.add('forge:sheets/iron', ['create:iron_sheet']);
    event.add('forge:sheets/gold', ['create:golden_sheet']);
    event.add('forge:sheets/brass', ['create:brass_sheet']);
    event.add('forge:sheets/zinc', ['createaddition:zinc_sheet']);
    event.add('forge:sheets/aluminum', ['tfmg:aluminum_sheet']);
    event.add('forge:sheets/nickel', ['tfmg:nickel_sheet']);
    event.add('forge:sheets/lead', ['tfmg:lead_sheet']);
    event.add('forge:sheets/platinum', ['createpropulsion:platinum_sheet']);
    event.add('forge:sheets/electrum', ['createaddition:electrum_sheet']);
    event.add('forge:sheets/rubber', ['tfmg:rubber_sheet']);
    event.add('forge:sheets/plastic', ['tfmg:plastic_sheet']);
    event.add('forge:sheets/cast_iron', ['tfmg:cast_iron_sheet']);
    event.add('forge:sheets/magnetic_alloy', ['tfmg:magnetic_alloy_sheet']);
});

ServerEvents.recipes(event => {
    // Убираем рецепт стали из смесителя Create Nuclear, чтобы сталь была единообразной.
    event.remove({ output: 'createnuclear:steel_ingot', type: 'create:mixing' });

    const steelIngots = [
        'createnuclear:steel_ingot',
        'createbigcannons:steel_ingot',
        'tfmg:steel_ingot'
    ];
    steelIngots.forEach(ingot => event.replaceInput({}, ingot, '#forge:ingots/steel'));

    const sheetReplacements = [
        ['create:copper_sheet', '#forge:sheets/copper'],
        ['create:iron_sheet', '#forge:sheets/iron'],
        ['create:golden_sheet', '#forge:sheets/gold'],
        ['create:brass_sheet', '#forge:sheets/brass'],
        ['createaddition:zinc_sheet', '#forge:sheets/zinc'],
        ['tfmg:aluminum_sheet', '#forge:sheets/aluminum'],
        ['tfmg:nickel_sheet', '#forge:sheets/nickel'],
        ['tfmg:lead_sheet', '#forge:sheets/lead'],
        ['createpropulsion:platinum_sheet', '#forge:sheets/platinum'],
        ['createaddition:electrum_sheet', '#forge:sheets/electrum'],
        ['tfmg:rubber_sheet', '#forge:sheets/rubber'],
        ['tfmg:plastic_sheet', '#forge:sheets/plastic'],
        ['tfmg:cast_iron_sheet', '#forge:sheets/cast_iron'],
        ['tfmg:magnetic_alloy_sheet', '#forge:sheets/magnetic_alloy']
    ];

    sheetReplacements.forEach(([item, tag]) => event.replaceInput({}, item, tag));
});