#This program runs the one max function in parallel on a single machine
#All available processors will be used automatically by the scoop function
#install deap with easy install deap

import random
import socket

from deap import base
from deap import creator
from deap import tools

#Scoop for parallelization
#This line is causing issues, specifically, getting a gaierror
#To fix this error, at least on mac, I had to enable any type of sharing in System Preferences > Sharing
from scoop import futures

from time import time


#Create fitnessmax class
creator.create("FitnessMax", base.Fitness, weights=(1.0,))
#Create individual class
creator.create("Individual", list, fitness=creator.FitnessMax)

#***************************************************************************************
#***************************************************************************************
#Create toolbox which will hold methods
toolbox = base.Toolbox()

#This is for parallelizing
#toolbox.register("map", futures.map)

#This will be used to generate random integers that will make up individuals
toolbox.register("attr_bool", random.randint, 0, 1)

# Structure initializers that will create individuals and populations
#Individuals are lists of 100 integers that will be zero or 1 as defined by the function attr_bool
toolbox.register("individual", tools.initRepeat, creator.Individual,toolbox.attr_bool, 100)
toolbox.register("population", tools.initRepeat, list, toolbox.individual)

#***************************************************************************************
#***************************************************************************************
#Create the evaluation function
#We want to work towards having one individual with all ones, i.e. a sum of 100
def evalOneMax(individual):
    return sum(individual)

#Create the genetic operators and put them in the toolbox
toolbox.register("evaluate", evalOneMax)
toolbox.register("mate", tools.cxTwoPoint)
toolbox.register("mutate", tools.mutFlipBit, indpb=0.05)
toolbox.register("select", tools.selTournament, tournsize=3)


#***************************************************************************************
#***************************************************************************************
#Create evolution function in the function main()
def main(CXPB = 0.1, MUTPB = 0.3):
    #Create the population of 300 individuals
    pop = toolbox.population(n=300)
    
    # Evaluate the entire population
    fitnesses = list(map(toolbox.evaluate, pop))
    for ind, fit in zip(pop, fitnesses):
        ind.fitness.values = [fit]
    
    # Extracting all the fitnesses of 
    fits = [ind.fitness.values[0] for ind in pop]
    
    # Variable keeping track of the number of generations
    g = 0
    
    # Begin the evolution
    while max(fits) < 100 and g < 1000:
        # A new generation
        g = g + 1
        print("-- Generation %i --" % g)
        
        # Select the next generation individuals
        offspring = toolbox.select(pop, len(pop))
        
        # Clone the selected individuals
        offspring = list(map(toolbox.clone, offspring))
        
        # Apply crossover and mutation on the offspring
        for child1, child2 in zip(offspring[::2], offspring[1::2]):
            if random.random() < CXPB:
                toolbox.mate(child1, child2)
                del child1.fitness.values
                del child2.fitness.values

        for mutant in offspring:
            if random.random() < MUTPB:
                toolbox.mutate(mutant)
                del mutant.fitness.values
                
        # Evaluate the individuals with an invalid fitness
        invalid_ind = [ind for ind in offspring if not ind.fitness.valid]
        fitnesses = map(toolbox.evaluate, invalid_ind)
        for ind, fit in zip(invalid_ind, fitnesses):
            ind.fitness.values = [fit]
            
        #Replace the old population by the offspring
        pop[:] = offspring
        
        # Gather all the fitnesses in one list and print the stats
        fits = [ind.fitness.values[0] for ind in pop]
        
        length = len(pop)
        mean = sum(fits) / length
        sum2 = sum(x*x for x in fits)
        std = abs(sum2 / length - mean**2)**0.5
        
        print("  Min %s" % min(fits))
        print("  Max %s" % max(fits))
        print("  Avg %s" % mean)
        print("  Std %s" % std)
        print(socket.gethostname())
    


#Call the function
start_time = time()
main()
end_time = time()

print end_time - start_time


