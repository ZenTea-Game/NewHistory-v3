// by MaxZT + AI — рецепты вина для Minecraft 1.21.1 / NeoForge 21.1.236.
// Рецепты задаются как обычный JSON Create через KubeJS event.custom:
// отдельное дополнение KubeJS для Create этой сборке не требуется.
ServerEvents.recipes(event => {
  // Заменяем исходные рецепты мода, сохраняя их штатные ID.
  event.remove({ id: 'create_alcoholic_beverages:winerecipe' })
  event.remove({ id: 'create_alcoholic_beverages:winebottlerecipe' })
  event.remove({ id: 'create_alcoholic_beverages:fine_winerecipe' })
  event.remove({ id: 'create_alcoholic_beverages:fine_winebottlerecipe' })

  // 1 виноград + 250 мБ воды -> 250 мБ вина в механическом смесителе.
  event.custom({
    type: 'create:mixing',
    ingredients: [
      { item: 'create_alcoholic_beverages:grapeitem' },
      { type: 'neoforge:single', amount: 250, fluid: 'minecraft:water' }
    ],
    results: [{ amount: 250, id: 'create_alcoholic_beverages:wine' }]
  }).id('newhistory:wine_from_grapes')

  // Стеклянная бутылка + 250 мБ вина -> бутылка вина в разливателе Create.
  event.custom({
    type: 'create:filling',
    ingredients: [
      { item: 'minecraft:glass_bottle' },
      { type: 'neoforge:single', amount: 250, fluid: 'create_alcoholic_beverages:wine' }
    ],
    results: [{ id: 'create_alcoholic_beverages:winebottle' }]
  }).id('newhistory:wine_bottle')

  // Гриб + 250 мБ вина -> 250 мБ изысканного вина в механическом смесителе.
  event.custom({
    type: 'create:mixing',
    ingredients: [
      { item: 'minecraft:brown_mushroom' },
      { type: 'neoforge:single', amount: 250, fluid: 'create_alcoholic_beverages:wine' }
    ],
    results: [{ amount: 250, id: 'create_alcoholic_beverages:fine_wine' }]
  }).id('newhistory:fine_wine')

  // Стеклянная бутылка + 250 мБ изысканного вина -> бутылка изысканного вина.
  event.custom({
    type: 'create:filling',
    ingredients: [
      { item: 'minecraft:glass_bottle' },
      { type: 'neoforge:single', amount: 250, fluid: 'create_alcoholic_beverages:fine_wine' }
    ],
    results: [{ id: 'create_alcoholic_beverages:finewinebottle' }]
  }).id('newhistory:fine_wine_bottle')
})
