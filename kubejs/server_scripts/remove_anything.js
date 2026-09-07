ServerEvents.recipes(event => {
    // Удаляем ВСЕ крафты (рецепты на выходе)
    event.remove({ output: 'anything:barrier_pickaxe' });
    event.remove({ output: 'anything:barrier_axe' });
    event.remove({ output: 'anything:barrier_shovel' });
    event.remove({ output: 'anything:barrier_hoe' });
    event.remove({ output: 'anything:barrier_sword' });

    // Удаляем рецепты, где они используются как ингредиент (на случай крафта улучшений)
    event.remove({ input: 'anything:barrier_pickaxe' });
    event.remove({ input: 'anything:barrier_axe' });
    event.remove({ input: 'anything:barrier_shovel' });
    event.remove({ input: 'anything:barrier_hoe' });
    event.remove({ input: 'anything:barrier_sword' });
});