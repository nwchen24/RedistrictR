import scores
import numpy as np
from random import randint

# This is the scoring function
# Note that it returns an iterable, of the same length as weights above
# We would basically have one master eval function, and then it would internally call the various metrics.
def evalOneMax(individual):
    # Since the goal is to get a list of all ones, the score is just the sum of the list.
    # All ones would give the highest possible score.
    return sum(individual),


def evalDistrict(individual):
    pass

def mutDistrict(individual, mutpb):
    pass

def cxDistrict(parent1, parent2, cxpb):
    pass

def eaDistrict(population, toolbox, cxpb, mutpb, ngen):
    pass

def initDistrict(data, adj, k):
    # Set n, the number of units to assign
    n = data.shape[0]

    # Initialize the solutions array with zeros (all unassigned)
    sol = np.zeros(n, dtype="int32")

    # Select k seed zones as starting elements
    seeds = data[data["outer_edge"] > 0].sample(k).index.values

    # Set solution assignments for the seed list
    for i, v in enumerate(seeds):
        sol[v] = i+1

    # Initialize the pool of zones to spread from with the seeds
    pool = seeds.tolist()

    # While there are still elements in the pool...
    while pool:
        # Select a zone available in the pool
        i = randint(0, len(pool)-1)

        # Pop out the selected item
        u = pool.pop(i)

        # Get the list of all zones adjacent to u
        for v in adj.rows[u]:
            # If the selected zone is unassigned, and not already in te pool...
            if sol[v] == 0 and v not in pool:
                # Add to the pool
                pool.append(v)
                # assign to the same district as u
                sol[v] = sol[u]

    return sol


    # while the pool is not empty
    #   pop unit u from the pool
    #   get adj, the list of units adjacent to u
    #   for each v in adj
    #       if solution[v] == 0 and v not in pool
    #           append v to pool
    #           solution[v] = solution[u]

    pass