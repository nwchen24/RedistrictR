import numpy as np
import pandas as pd
from collections import defaultdict
from random import randint
from math import pi, floor, ceil
from random import randint

data = None
adjacency = None
edges = None
max_mutation_units = 15
# TODO: initialize population thresholds.



#################################################################################################
# UTILITIES
#
# Functions used to calculate various statistics and get relevant subgroups of a given solution.
#################################################################################################


def bfs(G, origin):
    """
    Breadth-first search over a dict of adjacency lists. Returns a list of all the nodes in graph G that can be
    reached from the origin.

    :param G:
    :param origin:
    :return:
    """

    # Maintain a list of nodes already visited, to avoid repeats and loops
    visited = defaultdict(lambda: False)
    # An empty queue of nodes to traverse from
    queue = []
    # The list of all nodes that can be reached
    connected = []

    # Start with the provided origin in the queue
    queue.append(origin)
    visited[origin] = True

    # As long as there are still items in the queue
    while queue:
        # Pop out the first item, s
        s = queue.pop()

        # Add to the list of reachable nodes
        connected.append(s)

        # For all the neighbors...
        for i in G[s]:
            # If we haven't yet visited this neighbor...
            if not visited[i]:
                # Add the neighbor to the queue
                queue.append(i)
                # Mark it as visited
                visited[i] = True

    # Return the found list
    return connected


def edge_units(ind, src, dst):
    """Return a list of all units in the src zone of solution ind that are also adjacent to the dst zone.

    :param ind:
    :param src:
    :param dst:
    :return:
    """
    # Set of all units found
    units = set()

    src_zone = np.nonzero(ind == src)[0]
    dst_zone = np.nonzero(ind == dst)[0]

    # For each unit u in the source zone...
    for u in src_zone:
        # For each unit v adjacent to u...
        for v in adjacency.rows[u]:
            # If v is in the destination zone...
            if v in dst_zone:
                # Then u is an edge unit
                units |= set([u])
                # Don't need to look at any other units adjacent to u, if it's already confirmed an edge unit
                break
    return list(units)


def subzone_neighbors(ind, subzone, zid):
    """Return a list of all neighbors to a contiguous subgroup of units, which are in the same zone as that subgroup.

    :param ind:
    :param subzone:
    :param zid:
    :return:
    """

    # Initialize the set of neighbors.
    neighbors = set()

    # For each adjacency row matching a unit in the subzone...
    for r in adjacency.rows[subzone]:
        # Union in the adjacent units to neighbors
        neighbors |= set(r)

    # Only return those neighbors that are in the specified zone
    return [i for i in (neighbors - set(subzone)) if ind[i] == zid]


def contiguity_check(ind, subzone, src):
    """Check a move of units from one zone to another to make sure that it doesn't split the source zone. This is
    faster and easier to handle that checking the entire solution for contiguity after the fact. Takes an individual
    solution, a subzone of units being moved, and the zone id of the source of the subzone.

    :param ind:
    :param subzone:
    :param src:
    :return:
    """

    # If no subzones are being removed, then contiguity is not affected
    if len(subzone) == 0:
        return True

    # Get all the units that are neighbors of subzone, and in the same zone.
    neighbors = subzone_neighbors(ind, subzone, src)

    # G is the connectivity graph of the neighbors
    G = {}

    # For each neighboring unit...
    for u in neighbors:
        G[u] = []
        # Add to the graph only edges to the neighbors of u that are neighbors of the subzone.
        for v in adjacency.rows[u]:
            if v in neighbors:
                G[u].append(v)

    # Get the length of the number of units found by a breadth-first search of G
    c = len(bfs(G, list(G.keys())[0]))

    # If c = len(neighbors, then all adjacent, same-zoned units can still reach each other without subzone present.
    # This indicates that the source zones has not been split.
    return c > 0 and c == len(neighbors)


def initial(k):
    """Create an initial, semi-random, feasible solution, seeded with units from the outer edge.

    :param k:
    :return:
    """

    # TODO: Enforce population thresholds
    # TODO: Create alternate initial seedings

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



#################################################################################################
# OPERATORS
#
# Functions used to make evolutionary changes to solutions.
#################################################################################################


# src and dst are adjacent zones
def shift(ind, src, dst):
    """
    Given an individual solution (ind), and zone ids for the source and destination (src and dst), shift up to
    max_mutation_units from the source to the destination, without violating contiguity or population constraints.

    :param ind:
    :param src:
    :param dst:
    :return:
    """

    # TODO: Check against population constraints
    # TODO: Errors when there aren't valid moves to make (may not be major on larger problems)

    # Randomly select up to two adjacent units in src bordering on dst
    # TODO: current code only selects one
    eu = edge_units(ind, src, dst)
    if len(eu) == 0:
        return ind

    subzone = [np.random.choice(eu)]

    # while size of subzone < max mutation units
    while len(subzone) < max_mutation_units:
        # Get list of neighbor units of subzone that are in the same zone
        neighbors = subzone_neighbors(ind, subzone, src)
        if len(neighbors) > 0:
            # Get random number q in 1:|U|
            q = randint(1, len(neighbors))
            # Randomly choose subset of U with |U'| = q
            subset = np.random.choice(neighbors, q, replace=False)
            # subzone = subzone union U'
            subzone = list(set(subzone) | set(subset))

    if contiguity_check(ind, subzone, src):
        # dst = dst union subzone
        # src = src - subzone
        # aka reassign subzone to dst id
        for i in subzone:
            ind[i] = dst

    return ind


def mutate(ind):
    k = np.unique(ind).shape[0]
    zones = [i for i in range(1, k+1)]
    np.random.shuffle(zones)

    ## TODO: set these outside the function
    pop_threshold = 0.05
    total_pop = data["block_pop_total"].sum()
    min_pop = floor(total_pop*(1-pop_threshold))
    max_pop = ceil(total_pop*(1+pop_threshold))

    for z in zones:
        #
        print(z)

    return ind


def crossover(ind1, ind2):
    pass

#################################################################################################
# SCORES
#
# Functions used for generating scores for a given individual solution.
#################################################################################################


def perimeter(ind):
    #perimeters = np.zeros(len(np.unique(solution))+1)
    perimeters = pd.Series(np.zeros(len(np.unique(ind))), index=np.unique(ind))
    for i, row in enumerate(adjacency.rows):
        ai = ind[i]
        perimeters[ai] += data.iloc[i]["outer_edge"]
        for j in row:
            aj = int(data.iloc[j]["assignment"])
            if i < j and ai != aj:
                perimeters[ai] += edges[i, j]
                perimeters[aj] += edges[i, j]

    return perimeters


def compactness(ind):
    districts = np.unique(ind)
    perimeters = perimeter(data, adjacency, edges, ind)
    areas = data["area"].groupby(ind).sum()
    scores = 4*pi*areas/(perimeters**2)
    return scores.mean()
