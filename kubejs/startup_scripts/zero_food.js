StartupEvents.registry('item', event => {
    event.create('zero_food')
        .food(food => {
            // В новых версиях KubeJS используется nutrition вместо hunger
            food.nutrition(1) 
            food.saturation(0.1)
            
            // Эффект: Тошнота, 600 тиков (30 сек), уровень 4 (5-й уровень игры), шанс 0.3
            food.effect('minecraft:nausea', 600, 4, 0.3)
        })
})