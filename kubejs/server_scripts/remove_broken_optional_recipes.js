ServerEvents.recipes(event => {
    // Эти рецепты не имеют выходного предмета в установленной версии Create Things and Misc.
    event.remove({ id: 'create_things_and_misc:copper_scaffolding_craft' });
    event.remove({ id: 'create_things_and_misc:schematic_chair' });

    // Пустые шаблоны из мода Anything не являются настоящими рецептами.
    event.remove({ id: 'anything:barrier_boots' });
    event.remove({ id: 'anything:barrier_chestplate' });
    event.remove({ id: 'anything:barrier_helmet' });
    event.remove({ id: 'anything:barrier_leggings' });
});