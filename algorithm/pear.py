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

#NC add for dynamic selection of evaluation function
from sys import argv
import pymysql.cursors

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

#get the the list of geoIDs
geoIDs_list = district.data.GEOID

#**********************
#Go to the database and get the row corresponding to the tablerow argument input via the command line

#create the variable that will hold the result read from the target table in the database
weights_raw = None

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

print(weights_raw)

#*********************************************************************

# DEAP setup
# Populate weights based on input, from the targets database content
#creator.create("FitnessMax", base.Fitness, weights=(0.0001, 1.0, 0.0001))
creator.create("FitnessMax", base.Fitness, weights=(1.0,1.0,1.0))
creator.create("Individual", list, fitness=creator.FitnessMax)
toolbox = base.Toolbox()
toolbox.register("individual", district.initDistrict, creator.Individual, k)
toolbox.register("population", tools.initRepeat, list, toolbox.individual)
toolbox.register("evaluate", district.evaluate)
toolbox.register("mate", district.crossover)
toolbox.register("mutate", district.mutate)
toolbox.register("select", tools.selTournament, tournsize=3)

#initialize hall of fame
hall_of_fame_operative = tools.HallOfFame(maxsize = 100)



#*********************************************************************
#*********************************************************************
def main():
    pop = toolbox.population(n=population_size)
    fitnesses = list(map(toolbox.evaluate, pop))
    for ind, fit in zip(pop, fitnesses):
        ind.fitness.values = fit
    fits = [ind.fitness.values[0] for ind in pop]
    print(fits)


    for g in range(1, 101):
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
            compactness_score = individual_metric_scores_dict['compactness']
            cluster_proximity_score = individual_metric_scores_dict['cluster_proximity']
        except KeyError:
            pass

        #get weighted average fitness score used by the algorithm
        combined_fitness = individual.fitness.values[0]

        with connection.cursor() as cursor2:

            sql_solution_insert = "INSERT INTO solutions (fitness, vote_efficiency, compactness, cluster_proximity, target_id, id) VALUES (%s, %s, %s, %s, %s, %s);"
            cursor2.execute(sql_solution_insert, (str(combined_fitness), str(vote_efficiency_score), str(compactness_score), str(cluster_proximity_score), str(myargs['-tablerow']), solution_id_for_insert))

        #combine the individual assignments and the geoIDs into a dict which we will use to write to the assignments table in the DB
        individual_assignment_dict = dict(zip(geoIDs_list, individual))
        
        #write assignments to the assignments table
        #assignments table has columns:
        #geoid, solution_id, assignment, id
        with connection.cursor() as cursor3:
            
            for blockgroup_id in individual_assignment_dict.keys():  
                sql_assignment_insert = "INSERT INTO assignments (geoid, solution_id, assignment, id) VALUES(%s, %s, %s, %s);"
                cursor3.execute(sql_assignment_insert, (str(blockgroup_id), str(solution_id_for_insert), str(individual_assignment_dict[blockgroup_id]), None,))

    #commit sql commands
    connection.commit()

    #close the connection
    connection.close()

if __name__ == "__main__":
    main()





