import numpy as np
import pandas as pd
from collections import defaultdict
from random import randint
from math import pi, floor, ceil
from random import randint
import copy

#NC add for dynamic selection of evaluation function
import pymysql.cursors

data = None
adjacency = None
edges = None
max_mutation_units = None
pop_threshold = 0.05
pop_min = -1
pop_max = -1
debug = False

#NC add for dynamic selection of evaluation function
weights_raw = None

#################################################################################################
# UTILITIES
#
# Functions used to calculate various statistics and get relevant subgroups of a given solution.
#################################################################################################
def pop_range(k):
    pop_total = data["block_pop_total"].sum()

    min = floor((pop_total/k) * (1 - pop_threshold))
    max = ceil((pop_total/k) * (1 + pop_threshold))

    return min, max


def pop_summary(ind):
    k = np.unique(ind).shape[0]
    pops = data["block_pop_total"].groupby(ind).sum()
    pop_eval = np.zeros(k, dtype=np.int32)
    pop_eval[pops > pop_max] = 1
    pop_eval[pops < pop_min] = -1

    return pops, pop_eval


def pop_repair_units(pops, pop_eval):
    pop_target = floor(pops.sum())
    units = (50*(1-(pops/pop_target)**(-pop_eval))).astype("int")+1

    return units


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

    src_zone = np.nonzero(np.array(ind) == src)[0]
    dst_zone = np.nonzero(np.array(ind) == dst)[0]

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
    gkeys = list(G.keys())
    if len(gkeys) > 0:
        c = len(bfs(G, list(G.keys())[0]))
    else:
        c = 0

    # If c = len(neighbors, then all adjacent, same-zoned units can still reach each other without subzone present.
    # This indicates that the source zones has not been split.
    return c > 0 and c == len(neighbors)


def initial(k):
    """Create an initial, semi-random, feasible solution, seeded with units from the outer edge.

    :param k:
    :return:
    """


    # Set n, the number of units to assign
    n = data.shape[0]

    # Initialize the solutions array with zeros (all unassigned)
    sol = np.zeros(n, dtype="int32")

    # Select k seed zones as starting elements
    seeds = data[data["outer_edge"] > 0].sample(k).index.values

    # Keep a running tally of the zone populations
    zone_pops = defaultdict(lambda: 0)

    # Set solution assignments for the seed list, an initial populations for the zones
    for i, v in enumerate(seeds):
        zone_pops[i+1] = data.iloc[v]["block_pop_total"]
        sol[v] = i+1



    pool = seeds.tolist()
    # While there are still elements in the pool...
    while pool:
        # Get only the zone populations for units available in the pool
        tmp_pops = {i: v for i, v in zone_pops.items() if i in np.unique(sol[pool])}
        # Find the available zone with the smallest popultaion
        min_zone = min(tmp_pops, key=tmp_pops.get)
        # Find all the units in the pool that are part of the smallest zone
        min_zone_elements = np.where(sol[pool] == min_zone)
        # Randomly select one of these smallest-zone units
        i = np.random.choice(min_zone_elements[0], 1)[0]

        # Pop out the selected item
        u = pool.pop(i)

        # Get the list of all zones adjacent to u
        for v in adjacency.rows[u]:
            # If the selected unit is unassigned, and not already in the pool...
            if sol[v] == 0 and v not in pool:
                # Add to the pool
                pool.append(v)
                # assign to the same district as u
                sol[v] = sol[u]
                # Add to the zone population
                zone_pops[sol[u]] += data.iloc[v]["block_pop_total"]

    return list(sol)

#Alternative initial function that instead of generating random solutions, pulls solutions from the DB
def initial_fromDB(solution_id):
    # Connect to the database
    connection = pymysql.connect(host='redistrictr.cdm5j7ydnstx.us-east-1.rds.amazonaws.com',
                                 user='master',
                                 password='redistrictr',
                                 db='data',
                                 cursorclass=pymysql.cursors.DictCursor)

    #create the variable that will hold the results pulled from the DB
    results = None

    #pull all the assignments from the assignments table
    try:
        with connection.cursor() as cursor:
            # Read a single record
            sql = "SELECT * FROM `assignments` where solution_id = %s"
            cursor.execute(sql, (solution_id))
            results = cursor.fetchall()

    finally:
        connection.close()
        
    #initialize assignments_dict
    assignments_dict = {}

    #Put these in one long dict of type {geoid:assignment}
    for bg_assignment in results:
        assignments_dict[bg_assignment['geoid']] = bg_assignment['assignment']

    #order this dict to be in the order of the blockgroups in SD_data.csv
    SD_Data_blockgroup_order = list(data["GEOID"])

    #intialize list to hold assignments
    assignments_list_ordered = []

    #put blockgroup assignments into list pulling from the dict pulled from the DB, but using the SD Data blockgroup order
    for blockgroup in SD_Data_blockgroup_order:
        assignments_list_ordered.append(assignments_dict[str(blockgroup)])

    #assignments_list_ordered is the list we want to return in initial_fromDB
    return(assignments_list_ordered)

def solutionFromSplits(k, splits):
    n = len(splits)

    splitAssign = np.zeros(data.shape[0], dtype=np.int32)

    # Set split assignments for all
    for i, s in enumerate(splits):
        for u in s:
            splitAssign[u] = i

    adj = zone_adjacency(splitAssign)

    # List of indexes counts as a
    d = np.array([i for i in range(0, n)])
    outer = np.zeros(n)

    for i, s in enumerate(splits):
        for u in s:
            outer[i] += data.loc[u]["outer_edge"]

    # This part is very similar to initial, but modded to take direct input
    splitSol = np.zeros(n, dtype=np.int32)

    if d[outer > 0].shape[0] >= k:
        seeds = np.random.choice(d[outer > 0], k, replace=False)
    else:
        seeds = np.random.choice(d, k, replace=False)

    for i, v in enumerate(seeds):
        splitSol[v] = i+1
    pool = seeds.tolist()

    while pool:
        i = randint(0, len(pool)-1)
        u = pool.pop(i)

        for v in adj[u]:
            if splitSol[v] == 0 and v not in pool:
                pool.append(v)
                splitSol[v] = splitSol[u]

    sol = np.zeros(data.shape[0], dtype=np.int32)
    for i, s in enumerate(splits):
        for u in s:
            sol[u] = splitSol[i]

    return sol



#################################################################################################
# OPERATORS
#
# Functions used to make evolutionary changes to solutions.
#################################################################################################

def print_debug(message):
    if debug:
        print(message)

# src and dst are adjacent zones
def shift(ind, src, dst, units=max_mutation_units):
    print_debug("Source: %s; Destination: %s" % (src, dst))
    print_debug("Max Units: %s" % units)
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
    print_debug("Edge Units: %s" % eu)
    if len(eu) == 0:
        return ind

    subzone = [np.random.choice(eu)]

    # while size of subzone < max mutation units
    while len(subzone) < units:
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
    else:
        print_debug("Move tossed for breaking contiguity")

    return ind


def mutate(ind):
    k = np.unique(ind).shape[0]
    zones = [i for i in range(1, k+1)]
    np.random.shuffle(zones)
    # print(zones)

    for src in zones:
        pops, pop_eval = pop_summary(ind)
        # print(pops, pop_eval)
        if pops[src] > pop_min:
            zadj = zone_adjacency(ind)
            dst = np.random.choice(zadj[src], 1)[0]
            print_debug("[MUTATE] Running shift from %s to %s." % (src, dst))
            ind = shift(ind, src, dst, units=max_mutation_units)
        # else:
        #     print("[MUTATE] Skipped shift from %s because of pop_min check." % src)

    return list(ind)


def crossover(ind1, ind2):
    k = np.unique(ind1).shape[0]
    labels = []
    splits = defaultdict(lambda: set())

    # Loop over all indices in the solutions to produce initial splits
    for i in range(0, len(ind1)):
        # Any units that whose ind1 and ind2 assignments both match get placed into a split
        splits[(ind1[i], ind2[i])] |= set([i])

    newSplits = []

    # Loop over all splits to handle cases where a single split has gotten noncontiguous elements
    for key, s in splits.items():
        # Construct an adjacency graph dict of just the items in this split
        G = {}
        for u in s:
            G[u] = []
            for v in adjacency.rows[u]:
                if v in s:
                    G[u].append(v)

        # while there are still units in s...
        while len(s) > 0:
            # Pop the first item from s, and construct a bfs spanning tree from it
            origin = s.pop()
            span = bfs(G, origin)
            newSplits.append(span)

            # Remove these units from s
            s = s - set(span)

            # Remove these units from the graph
            ng = {}
            for i, v in G.items():
                if i not in span:
                    ng[i] = list(set(G[i]) - set(span))
            G = copy.deepcopy(ng)

    #print(newSplits)
    return solutionFromSplits(k, newSplits)


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
            aj = int(ind[j])
            if i < j and ai != aj:
                perimeters[ai] += edges[i, j]
                perimeters[aj] += edges[i, j]

    return perimeters


def compactness(ind):
    districts = np.unique(ind)
    perimeters = perimeter(ind)
    areas = data["area"].groupby(ind).sum()
    scores = 4*pi*areas/(perimeters**2)
    return scores.mean()


# ***************************************************************************
# Cluster Proximity Function
# ***************************************************************************
def cluster_proximity(cluster_var, ind):
    # add assignment list as a column
    data['district_assignment'] = ind

    grouped_by_dist = data[['district_assignment', cluster_var]].groupby(by=['district_assignment', cluster_var]).size()

    # format the dataframe
    grouped_by_dist = grouped_by_dist.reset_index(name='counts')
    grouped_by_dist.columns = grouped_by_dist.columns.get_level_values(0)

    # reshape to wide
    grouped_by_dist = grouped_by_dist.pivot(index='district_assignment', columns='all_cluster', values='counts')

    # reset column names
    grouped_by_dist = grouped_by_dist.reset_index()
    grouped_by_dist.columns = grouped_by_dist.columns.get_level_values(0)

    # subset columns
    grouped_by_dist = grouped_by_dist[['district_assignment', 1, 2, 3, 4, 5]]

    # replace NA with zero
    grouped_by_dist = grouped_by_dist.fillna(value=0)

    # Get total number of block groups in each district
    grouped_by_dist['total_blockgroups'] = grouped_by_dist[1] + grouped_by_dist[2] + grouped_by_dist[3] + \
                                           grouped_by_dist[4] + grouped_by_dist[5]

    # Get share of each district accounted for by block groups in each cluster
    grouped_by_dist['cluster_1_share'] = grouped_by_dist[1] / grouped_by_dist['total_blockgroups']
    grouped_by_dist['cluster_2_share'] = grouped_by_dist[2] / grouped_by_dist['total_blockgroups']
    grouped_by_dist['cluster_3_share'] = grouped_by_dist[3] / grouped_by_dist['total_blockgroups']
    grouped_by_dist['cluster_4_share'] = grouped_by_dist[4] / grouped_by_dist['total_blockgroups']
    grouped_by_dist['cluster_5_share'] = grouped_by_dist[5] / grouped_by_dist['total_blockgroups']

    # get the max proximity for each district
    grouped_by_dist['max_proximity'] = grouped_by_dist[
        ['cluster_1_share', 'cluster_2_share', 'cluster_3_share', 'cluster_4_share', 'cluster_5_share']].max(axis=1)

    return np.mean(grouped_by_dist['max_proximity'])


def vote_efficiency_gap(ind):
    # add assignment list as a column
    data['district_assignment'] = ind

    grouped_by_dist = data[['district_assignment', 'Dem_votes_Pres_08', 'Rep_votes_Pres_08']].groupby(
        by=['district_assignment']).agg(['sum'])

    # format the dataframe
    grouped_by_dist = grouped_by_dist.reset_index()
    grouped_by_dist.columns = grouped_by_dist.columns.get_level_values(0)

    # get winner for each district
    grouped_by_dist['winner'] = np.where(grouped_by_dist['Dem_votes_Pres_08'] > grouped_by_dist['Rep_votes_Pres_08'],
                                         'Dem', 'Rep')

    # get wasted democratic and replublican votes (i.e. votes above the winning threshold)
    grouped_by_dist['dem_wasted'] = np.where(grouped_by_dist['winner'] == 'Dem',
                                             grouped_by_dist['Dem_votes_Pres_08'] - grouped_by_dist[
                                                 'Rep_votes_Pres_08'],
                                             grouped_by_dist['Dem_votes_Pres_08'])
    grouped_by_dist['rep_wasted'] = np.where(grouped_by_dist['winner'] == 'Rep',
                                             grouped_by_dist['Rep_votes_Pres_08'] - grouped_by_dist[
                                                 'Dem_votes_Pres_08'],
                                             grouped_by_dist['Rep_votes_Pres_08'])

    # get total wasted votes for each party
    dem_wasted_votes = np.sum(grouped_by_dist['dem_wasted'])
    rep_wasted_votes = np.sum(grouped_by_dist['rep_wasted'])

    # Calculate efficiency gap and efficiency gap percentage
    efficiency_gap = abs(dem_wasted_votes - rep_wasted_votes)
    efficiency_gap_pct = efficiency_gap / (
    np.sum(grouped_by_dist['Dem_votes_Pres_08']) + np.sum(grouped_by_dist['Rep_votes_Pres_08']))

    del data['district_assignment']

    return (efficiency_gap_pct)

def zone_adjacency(ind):
    zadj = defaultdict(lambda: [])
    for u in range(0, len(ind)):
        for v in adjacency.rows[u]:
            if ind[u] != ind[v]:
                zadj[ind[u]] = list(set(zadj[ind[u]]) | set([ind[v]]))
                zadj[ind[v]] = list(set(zadj[ind[v]]) | set([ind[u]]))

    return zadj

def population_score(ind):
    pops, _ = pop_summary(ind)
    return (pop_max - pop_min) / (pops.max() - pops.min())

def pop_repair(ind):
    # Initialize number of iterations that have passed
    count = 0

    # Get a map of which zones are adjacent to each other
    zadj = zone_adjacency(ind)

    # Initial evaluation of the population evenness metrics
    pops, pop_eval = pop_summary(ind)

    while np.any(pop_eval != 0):
        print(pops, pop_eval)
        if np.any(pop_eval == 1):
            src = pops.idxmax()
            srcadj = zadj[src]
            dst = pops[srcadj].idxmin()

            # while pop_eval[dst-1] > 0:
            #     src = dst
            #     srcadj = zadj[src]
            #     dst = pops[srcadj].idxmin()

            #ind = shift(ind, src, dst, units=pop_repair_units(pops, pop_eval)[src])
            ind = shift(ind, src, dst, units=1)
            pops, pop_eval = pop_summary(ind)
            print("High to low: %s, %s" % (src, dst))

        elif np.any(pop_eval == -1):
            dst = pops.idxmin()
            dstadj = zadj[dst]
            src = pops[dstadj].idxmax()

            # while pop_eval[src-1] < 0:
            #     dst = src
            #     dstadj = zadj[dst]
            #     src = pops[dstadj].idxmax()

            ind = shift(ind, src, dst, units1)
            pops, pop_eval = pop_summary(ind)
            print("Low to high: %s, %s" % (src, dst))

        #ind = shift(ind, src, dst, units=5)
        count += 1
        if(count > 5000):
            ind = initial(pops.shape[0])
            count = 0
        zadj = zone_adjacency(ind)
        print(count)
        np.savetxt("../data/progress.csv", ind, fmt="%i")

    print(pops, pop_eval)
    return ind

#*****************************************************
#smart dispatcher that uses the column names in the target DB table
#This dispatcher is a dict that maps column names from the target DB references to each of the evaluation metric functions defined in this file
#Keys are the names of the columns in the target DB table
#if we add additional functionality to incorporate other evaluation metrics, they will need to be added to this dispatcher in the forma of:
#{target DB table col: function in this file}
dispatcher = {'compactness': compactness, 'vote_efficiency': vote_efficiency_gap, 'cluster_proximity':cluster_proximity}

def evaluate(ind):

    #instantiate a list to hold the evaluation metric functions we want to incorporate
    func_list = []

    #weights_raw is the table row pulled from the target table of the DB
    #if the flag for a given evaluation metric is equal to 1 in that row of the target table,
    #then that evaluation metric will be included in the evaluation function fed to the algorithm
    for i in weights_raw.keys():
        if (weights_raw[i] == 1) & (i != "id"):
            if i == "cluster_proximity":
                func_list.append(dispatcher[i]('all_cluster', ind))
            else:
                func_list.append(dispatcher[i](ind))

    return tuple(func_list)

#supplementary helper evaluate function to be able to get the order of the 
def evaluate_metric_order_helper(ind):

    #instantiate a list to hold the evaluation metric functions we want to incorporate
    func_list = []

    #weights_raw is the table row pulled from the target table of the DB
    #if the flag for a given evaluation metric is equal to 1 in that row of the target table,
    #then that evaluation metric will be included in the evaluation function fed to the algorithm
    for i in weights_raw.keys():
        if (weights_raw[i] == 1) & (i != "id"):
            func_list.append(dispatcher[i].__name__)

    return func_list

def initDistrict(container, k):
    return container(initial(k))


#Alternative initDistrict function to pull solutions from the DB
def initDistrict_fromDB(container, solution_id):
    return container(initial_fromDB(solution_id))

