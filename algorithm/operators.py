import scores
import numpy as np
import utils
from random import randint
import configparser



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

def initDistrict(data, adjacency, k):

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
        for v in adjacency.rows[u]:
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


# src and dst are adjacent zones
def shiftDistrict(adjacency, ind, src, dst):
    # Randomly select up to two adjacent units in src bordering on dst
    # TODO: current code only selects one
    eu = utils.edge_units(adjacency, ind, src, dst)
    if len(eu) == 0:
        return ind

    subzone = [np.random.choice(eu)]

    # while size of subzone < max mutation units
    while len(subzone) < max_mutation_units:
        # Get list of neighbor units (U) of subzone
        neighbors = utils.subzone_neighbors(adjacency, ind, subzone, src)
        if len(neighbors) > 0:
            # Get random number q in 1:|U|
            q = randint(1, len(neighbors))
            # Randomly choose subset of U with |U'| = q
            subset = np.random.choice(neighbors, q, replace=False)
            # subzone = subzone union U'
            subzone = list(set(subzone) | set(subset))

    if utils.contiguity_check(adjacency, ind, subzone, src):
        # dst = dst union subzone
        # src = src - subzone
        # aka reassign subzone to dst id
        for i in subzone:
            ind[i] = dst

    return ind