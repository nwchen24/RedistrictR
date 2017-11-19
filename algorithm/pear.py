import configparser
import utils
import district
import random
import numpy as np
import pandas as pd
from math import floor
import csv

from deap import base
from deap import creator
from deap import tools

# Import configuration and initialize the district module
section = "pear"
config = configparser.ConfigParser()
config.read("settings.cfg")

district.data, district.adjacency, district.edges = utils.loadData(config.get(section, "dataset"))
district.max_mutation_units = config.getint(section, "max_mutation_units")
district.pop_threshold = config.getfloat(section, "pop_threshold")

crossover_prob, mutation_prob = config.getfloat(section, "crossover_prob"), config.getfloat(section, "mutation_prob")
population_size = config.getint(section, "population_size")

k = config.getint(section, "num_districts")

# DEAP setup
# Populate weights based on input, from the targets database content
#creator.create("FitnessMax", base.Fitness, weights=(0.0001, 1.0, 0.0001))
creator.create("FitnessMax", base.Fitness, weights=(1.0,))
creator.create("Individual", list, fitness=creator.FitnessMax)
toolbox = base.Toolbox()
toolbox.register("individual", district.initDistrict, creator.Individual, k)
toolbox.register("population", tools.initRepeat, list, toolbox.individual)
toolbox.register("evaluate", district.evaluate)
toolbox.register("mate", district.crossover)
toolbox.register("mutate", district.mutate)
toolbox.register("select", tools.selTournament, tournsize=3)


def main():
    pop = toolbox.population(n=population_size)
    fitnesses = list(map(toolbox.evaluate, pop))
    for ind, fit in zip(pop, fitnesses):
        ind.fitness.values = fit

    fits = [ind.fitness.values[0] for ind in pop]
    print(fits)

    for g in range(1, 1001):
        print("-- Generation %i --" % g)
        offspring = toolbox.select(pop, population_size)
        offspring = list(map(toolbox.clone, offspring))

        for child1, child2 in zip(offspring[::2], offspring[1::2]):
            if random.random() < crossover_prob:
                # In onemax this function modifies both in place to turn them into two new options
                # The PEAR version only creates one new solution, not in place. just append to offspring?
                offspring.append(creator.Individual(toolbox.mate(child1, child2)))

        for mutant in offspring:
            if random.random() < mutation_prob:
                mutant = creator.Individual(toolbox.mutate(mutant))
                del mutant.fitness.values

        invalid_ind = [ind for ind in offspring if not ind.fitness.valid]
        fitnesses = map(toolbox.evaluate, invalid_ind)
        for ind, fit in zip(invalid_ind, fitnesses):
            ind.fitness.values = fit

        pop[:] = offspring

        # Check performance stats
        fits = [ind.fitness.values[0] for ind in pop]
        length = len(pop)
        mean = sum(fits) / length
        sum2 = sum(x*x for x in fits)
        std = abs(sum2 / length - mean**2)**0.5

        print("  Min %s" % min(fits))
        print("  Max %s" % max(fits))
        print("  Avg %s" % mean)
        print("  Std %s" % std)
        print("  Pop Count: %s" % len(fits))
        # print(pop)

    print(pop)


if __name__ == "__main__":
    main()