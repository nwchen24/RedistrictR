import configparser
import utils
import district
import numpy as np
import pandas as pd
from math import floor
import csv

section = "functiontest"
config = configparser.ConfigParser()
config.read("settings.cfg")

district.data, district.adjacency, district.edges, district.qadjacency = utils.loadData(config.get(section, "dataset"))
district.max_mutation_units = config.getint(section, "max_mutation_units")
district.pop_threshold = config.getfloat(section, "pop_threshold")
district.debug = True

k = config.getint(section, "num_districts")


def writeSolution(ind, filename="assignments.csv"):
    geoids = district.data["GEOID"].values

    with open("../data/%s" % filename, "a") as assn:
        assn_wr = csv.writer(assn, lineterminator="\n")
        for a, assignment in enumerate(ind):
            geoid = geoids[a]
            assn_wr.writerow([geoid, assignment])
        assn.close()


def produceSolutions():
    # Produce solutions for Nikki's database
    num_targets = 3
    num_solutions = 100
    # Loop through possible targets
    for t in range(0, num_targets):
        target_id = t + 1
        for s in range(0, num_solutions):
            solution_id = t * num_solutions + s + 1
            ind = district.initial(k)
            comp = district.compactness(ind)
            clust = district.cluster_proximity("all_cluster", ind)
            vote = district.vote_efficiency_gap(ind)
            # print(solution_id,target_id,comp,clust,vote)

            geoids = district.data["GEOID"].values

            with open("../data/tables/solutions.csv", "a") as sol:
                sol_wr = csv.writer(sol, lineterminator="\n")
                sol_wr.writerow([solution_id, target_id, comp, clust, vote])
                sol.close()

            with open("../data/tables/assignments.csv", "a") as assn:
                assn_wr = csv.writer(assn, lineterminator="\n")
                for a, assignment in enumerate(ind):
                    assignment_id = (solution_id - 1) * len(ind) + a + 1
                    geoid = geoids[a]
                    # print(assignment_id, solution_id, geoid, assignment)
                    assn_wr.writerow([assignment_id, solution_id, geoid, assignment])
                assn.close()

def main():
    district.pop_min, district.pop_max = district.pop_range(k)

    ind = district.initial(k)
    pops, pop_eval = district.pop_summary(ind)
    pop_score = district.population_score(ind)
    pop_score_2 = district.population_score_2(ind)

    print("===================")
    print("-- INITIAL STATE --")
    print("===================")
    print("- Populations: -")
    print(pops)
    print("- Population Evaluation -")
    print(pop_eval)

    # src = pops.idxmax()
    # dst = pops.idxmin()

    # src_per_unit = np.floor(pops/district.data.groupby(ind).size())[src]
    # diff = pops[src] - pops[dst]

    # units = floor(diff/src_per_unit)
    # units = district.pop_repair_units(ind, pops, src, dst)

    # print("===================")
    # print("-- SHIFT ATTEMPT --")
    # print("===================")
    # print("Source: %s; Destination: %s" % (src, dst))
    # print("Attempting to shift: %s" % units)
    #
    # ind2 = district.shift(ind, src, dst, units=units)
    # pops2, pop_eval2 = district.pop_summary(ind2)
    #
    # print("- Populations: -")
    # print(pops)
    # print("- Population Evaluation")
    # print(pop_eval)

    # print("- Population Score -")
    # print(pop_score)
    # print("- Population Score 2 -")
    # print(pop_score_2)

    district.writeSolution(ind, "000_initial.csv")

    ind = district.pop_repair(ind)

    district.writeSolution(ind, "000_final.csv")

    # TESTING WHY SHIFT DIDN'T WORK
    # sol = pd.read_csv("../data/000_progress_1046.csv", names=["geoid", "assignment"])
    # ind = sol["assignment"].values
    # pops, pop_eval = district.pop_summary(ind)
    #
    # print("=== Initial Stats ===")
    # print(pops)
    # print(pop_eval)
    # print(district.population_score(ind))
    #
    # print("=== Shift Attempt ===")
    # ind = district.shift(ind, 5, 1, 1, subzone=[1457])
    # print(district.population_score(ind))


if __name__ == "__main__":
    main()