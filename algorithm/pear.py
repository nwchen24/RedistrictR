import configparser
import utils
import district
import numpy as np
import pandas as pd
from math import floor
import csv

from deap import base
from deap import creator
from deap import tools

# Import configuration and initialize the district module
section = "functiontest"
config = configparser.ConfigParser()
config.read("settings.cfg")

district.data, district.adjacency, district.edges = utils.loadData(config.get(section, "dataset"))
district.max_mutation_units = config.getint(section, "max_mutation_units")
district.pop_threshold = config.getfloat(section, "pop_threshold")

k = config.getint(section, "num_districts")

# DEAP setup
# Populate weights based on input, from the targets database content
creator.create("FitnessMax", base.Fitness, weights=(1.0, 0.0001, 0.0001))
creator.create("Individual", list, fitness=creator.FitnessMax)
toolbox = base.Toolbox()
toolbox.register("individual", district.initDistrict, creator.Individual, k)
toolbox.register("population", tools.initRepeat, list, toolbox.individual)
toolbox.register("evaluate", district.evaluate)
toolbox.register("mate", district.crossover)
toolbox.register("mutate", district.mutate)
toolbox.register("select", tools.selTournament, tournsize=3)


def main():
    pop = toolbox.population(n=10)
    fitnesses = list(map(toolbox.evaluate, pop))
    for ind, fit in zip(pop, fitnesses):
        ind.fitness.values = fit

    fits = [ind.fitness.values[0] for ind in pop]
    print(fits)




if __name__ == "__main__":
    main()