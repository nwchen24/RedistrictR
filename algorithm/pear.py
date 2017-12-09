import configparser
import utils
import district
import random
import numpy as np
import pandas as pd
from math import floor
import csv
from time import time

from deap import base
from deap import creator
from deap import tools

#NC add for dynamic selection of evaluation function
from sys import argv
import pymysql.cursors

# Import configuration and initialize the district module
section = "minipear"
config = configparser.ConfigParser()
config.read("settings.cfg")

district.data, district.adjacency, district.edges, district.qadjacency = utils.loadData(config.get(section, "dataset"))
district.max_mutation_units = config.getint(section, "max_mutation_units")
district.pop_threshold = config.getfloat(section, "pop_threshold")
district.pop_min, district.pop_max = district.pop_range(k)

crossover_prob, mutation_prob = config.getfloat(section, "crossover_prob"), config.getfloat(section, "mutation_prob")
population_size = config.getint(section, "population_size")
generations = config.getint(section, "generations")

k = config.getint(section, "num_districts")

#get the the list of geoIDs
geoIDs_list = district.data.GEOID

#**********************
#Go to the database and get the row corresponding to the tablerow argument input via the command line

#create the variable that will hold the result read from the target table in the database
weights_raw = None

# TEMP: Remove this after testing
# weights_raw = {"compactness": 1}

#NC get weights from the target table in the database
#NOTE: Not sure whether this too should be included inside of the main() function
#If we want to include this section inside of the main() function, need to figure out how to set global variable district.weights_raw inside of the main() function

#read in the commmand line arguments into a dict called myargs
myargs = utils.getopts(argv)

#Connect to the database
connection = pymysql.connect(host='redistrictr.cdm5j7ydnstx.us-east-1.rds.amazonaws.com',
    user='master',
    password='redistrictr',
    db='data',
    cursorclass=pymysql.cursors.DictCursor)

#Get the weights corresponding to the target table row from the command line
#try:
with connection.cursor() as cursor:
    # Read a single record
    sql = "SELECT * FROM `targets` WHERE `id`=%s"
    cursor.execute(sql, (str(myargs['-tablerow']),))
    weights_raw = cursor.fetchone()

    #get the max id in the solutions table
    sql2 = "SELECT MAX(solution_id) FROM assignments"
    cursor.execute(sql2, ())
    starting_solution_id = cursor.fetchone()['MAX(solution_id)']

connection.close()

#set weights_raw in the district module equal to what was read in from the database
district.weights_raw = weights_raw
#
# print(weights_raw)

#*********************************************************************

# DEAP setup
# Populate weights based on input, from the targets database content
#creator.create("FitnessMax", base.Fitness, weights=(0.0001, 1.0, 0.0001))
creator.create("FitnessMax", base.Fitness, weights=(1.0,1.0,1.0))
#create a type describing individuals in the population: individuals are simple lists
creator.create("Individual", list, fitness=creator.FitnessMax)
toolbox = base.Toolbox()
toolbox.register("individual", district.initDistrict, creator.Individual, k)
toolbox.register("population", district.initMap, list, toolbox.individual, mapfunc=toolbox.map)
toolbox.register("evaluate", district.evaluate)
toolbox.register("mate", district.crossover)
toolbox.register("mutate", district.mutate)
toolbox.register("select", tools.selTournament, tournsize=3)

#initialize hall of fame
hall_of_fame_operative = tools.HallOfFame(maxsize = 5)



#*********************************************************************
#*********************************************************************
def main():
    print("== Building initial population ==")
    pop_start_time = time()
    
    #create a population creating half of individuals using random initialization from above and pulling half from the database
    #get IDs of solutions we want to pull from the DB

    #*****************************************************************
    #get the IDs of solutions that we want to pull from the DB
    #Connect to the database
    connection = pymysql.connect(host='redistrictr.cdm5j7ydnstx.us-east-1.rds.amazonaws.com',
                                 user='master',
                                 password='redistrictr',
                                 db='data',
                                 cursorclass=pymysql.cursors.DictCursor)

    #create the variable that will hold the result
    results = None

    #pull rows from the solutions table that were optimized according to the given target ID
    try:
        with connection.cursor() as cursor:
            # Read a single record
            sql = "SELECT * FROM solutions where target_id = %s ORDER BY -fitness"
            cursor.execute(sql, (str(myargs['-tablerow']),))
            results = cursor.fetchall()

    finally:
        connection.close()
        
    #put solution IDs we want to pull in a list
    solution_ID_list = []

    for solution in results:
        solution_ID_list.append(solution['id'])

    #*****************************************************************
    #pull half of the solutions from the DB (or if that many are not available, then pull all possible solutions from the DB)
    num_solutions_from_DB = 0

    #check length of solutions pulled from DB to check if there are enough to make up half of the population
    #if there are not enough solutions in the DB to make up half of our population, then pull all of them from the DB
    if len(solution_ID_list) <= population_size / 2:
        
        #initialize list to hold population from DB
        pop_fromDB = []

        #loop through the solution ID list to create a population of individuals pulled from the DB
        for solution in solution_ID_list:
            toolbox.register("individual_fromDB", district.initDistrict_fromDB, creator.Individual, solution)
            ind_fromDB = toolbox.individual_fromDB()
            pop_fromDB.append(ind_fromDB)
        
        num_solutions_from_DB = len(solution_ID_list)
        print("Less than half of initial districts from DB")
        print(str(num_solutions_from_DB) + "/" + str(population_size) + " individuals used from DB")

    #otherwise, keep the the first n solution IDs in the list where n is half of the population size and pull those solutions
    else:
        new_solution_ID_list = solution_ID_list[:round(population_size / 2)]
        
        #initialize list to hold population from DB
        pop_fromDB = []

        #loop through the solution ID list to create a population of individuals pulled from the DB
        for solution in new_solution_ID_list:
            toolbox.register("individual_fromDB", district.initDistrict_fromDB, creator.Individual, solution)
            ind_fromDB = toolbox.individual_fromDB()
            pop_fromDB.append(ind_fromDB)
            
        num_solutions_from_DB = len(new_solution_ID_list)
        print("Half of initial districts from DB")
        print(str(len(new_solution_ID_list)) + " individuals used from DB")

    #generate the number of remaining individuals using random initialization
    pop_random = toolbox.population(n=population_size - num_solutions_from_DB)

    #merge the individuals pulled from the DB and those that were randomly initialized
    pop = pop_fromDB + pop_random

    fitnesses = list(map(toolbox.evaluate, pop))

    for ind, fit in zip(pop, fitnesses):
        ind.fitness.values = fit
    fits = [ind.fitness.values[0] for ind in pop]
    pop_end_time = time()
    pop_duration = pop_end_time - pop_start_time
    print("%s solutions initialized in %s seconds (%s per solution)" % (population_size, pop_duration, floor(pop_duration/population_size)))


    # Evolve for the number of generations requested
    for g in range(1, generations+1):
        print("-- Generation %i --" % g)
        generation_start_time = time()

        # Use the selection operator to limit the population down to population_size
        # After each generation the overall population will be slightly larger, due to the crossover operation.
        offspring = toolbox.select(pop, population_size)

        # Do a deep copy of the offspring, so they do not directly edit the current population
        offspring = list(toolbox.map(toolbox.clone, offspring))

        # Crossover operation: loop over every possible pair in the population, attempting crossover
        for child1, child2 in zip(offspring[::2], offspring[1::2]):
            # Choose pairs to mate via an independent probability
            if random.random() < crossover_prob:
                # Run the crossover operation and append the child to the population
                offspring.append(creator.Individual(toolbox.mate(child1, child2)))

        # Mutation operation: loop over every individual in the population, attempting crossover
        for mutant in offspring:
            # Choose which individuals mutate via an independent probability
            if random.random() < mutation_prob:
                # Run the mutation operation, which edits the individual in place.
                mutant = creator.Individual(toolbox.mutate(mutant))
                # Invalidate the fitness for this individual, because it has changed
                del mutant.fitness.values

        # Get a list of all the individuals in the offspring with an invalid fitness score.
        # These are all the new individuals, either children or mutants
        invalid_ind = [ind for ind in offspring if not ind.fitness.valid]
        # Calculate the new fitness scores for these individuals, and attach
        fitnesses = toolbox.map(toolbox.evaluate, invalid_ind)
        for ind, fit in zip(invalid_ind, fitnesses):
            ind.fitness.values = fit

        # Replace the population with the offspring
        pop[:] = offspring
        generation_end_time = time()
        generation_duration = generation_end_time - generation_start_time

        # Post generation operations, like logging and outputting stats
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
        print("\nGeneration completed in %s seconds\n" % generation_duration)

    #Once the algorithm is finished running, update the hall of fame
    hall_of_fame_operative.update(pop)
    
    #get the ordering of the metrics returned in the tuple resulting from the evaluation function.
    metric_score_order = district.evaluate_metric_order_helper(hall_of_fame_operative[0])

    #open database connection
    connection = pymysql.connect(host='redistrictr.cdm5j7ydnstx.us-east-1.rds.amazonaws.com',
                             user='master',
                             password='redistrictr',
                             db='data',
                             cursorclass=pymysql.cursors.DictCursor)

    #set the start of the solution table ID
    solution_id_for_insert = starting_solution_id

    for individual in hall_of_fame_operative:

        #increment the solution id
        solution_id_for_insert += 1
        print(solution_id_for_insert)
        
        #*************************************
        #write solution and its fitness / evaluation scores to the solutions table
        #solutions table has columns:
        #fitness, vote_efficiency, compactness, cluster_proximity, target_id, id

        #put the scores for each metric in a dict like this {compactness: 0.9999, vote_efficiency: 0.9999, cluster_proximity: 0.9999}
        hof_individual_metrics_list = list(district.evaluate(individual))
        individual_metric_scores_dict = dict(zip(metric_score_order, hof_individual_metrics_list))

        #instantiate individual metric scores to None, then replace with scores that were evaluated based on the current target ID
        vote_efficiency_score = None
        compactness_score = None
        cluster_proximity_score = None

        try:
            vote_efficiency_score = individual_metric_scores_dict['vote_efficiency_gap']
        except KeyError:
            pass

        try:    
            compactness_score = individual_metric_scores_dict['compactness']
        except KeyError:
            pass

        try:    
            cluster_proximity_score = individual_metric_scores_dict['cluster_proximity']
        except KeyError:
            pass

        #get weighted average fitness score used by the algorithm
        combined_fitness = individual.fitness.values[0]

        with connection.cursor() as cursor2:

            print("inserting to solution")

            sql_solution_insert = "INSERT INTO solutions (fitness, vote_efficiency, compactness, cluster_proximity, target_id, id) VALUES (%s, %s, %s, %s, %s, %s);"
            cursor2.execute(sql_solution_insert, (str(combined_fitness), str(vote_efficiency_score), str(compactness_score), str(cluster_proximity_score), str(myargs['-tablerow']), solution_id_for_insert))

        #combine the individual assignments and the geoIDs into a dict which we will use to write to the assignments table in the DB
        individual_assignment_dict = dict(zip(geoIDs_list, individual))
        
        #write assignments to the assignments table
        #assignments table has columns:
        #geoid, solution_id, assignment, id

        #create a list of tuples to put into the assignments table
        assignments_insert_data = []

        for blockgroup_id in individual_assignment_dict.keys():
            assignments_insert_data.append((str(blockgroup_id), str(solution_id_for_insert), str(individual_assignment_dict[blockgroup_id]), None))

        with connection.cursor() as cursor3:
            
            print("inserting to assignments")
            #for blockgroup_id in individual_assignment_dict.keys():  
            sql_assignment_insert = "INSERT INTO assignments (geoid, solution_id, assignment, id) VALUES(%s, %s, %s, %s);"
            #cursor3.execute(sql_assignment_insert, (str(blockgroup_id), str(solution_id_for_insert), str(individual_assignment_dict[blockgroup_id]), None,))
            cursor3.executemany(sql_assignment_insert, assignments_insert_data)


    #commit sql commands
    connection.commit()

    #close the connection
    connection.close()


if __name__ == "__main__":
    main()





