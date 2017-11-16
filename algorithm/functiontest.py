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

district.data, district.adjacency, district.edges = utils.loadData(config.get(section, "dataset"))
district.max_mutation_units = config.getint(section, "max_mutation_units")
district.pop_threshold = config.getfloat(section, "pop_threshold")

k = config.getint(section, "num_districts")

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
    i1 = district.initial(k)
    i2 = district.mutate(i1)
    i3 = district.crossover(i1, i2)


    # np.savetxt("../data/ind1.")
    # pops, pop_eval = district.pop_summary(ind)
    # print(pops)
    # print(district.population_score(ind))
    # print(np.unique(ind, return_counts=True))
    # np.savetxt("../data/evenpopinit.csv", ind, fmt="%i")
    # adj = district.pop_repair(ind)
    # np.savetxt("../data/evenpopadj.csv", adj, fmt="%i")

    # ind1 = district.initial(k)
    # ind2 = district.initial(k)
    # new = district.crossover(ind1, ind2)
    #
    # np.savetxt("../data/ind1.csv", ind1, fmt="%i")
    # np.savetxt("../data/ind2.csv", ind2, fmt="%i")
    # np.savetxt("../data/new.csv", new, fmt="%i")


    # pop_target = floor(district.data["block_pop_total"].sum()/k)
    # print(pop_target)

    # min = floor((pop_total/k) * (1 - pop_threshold))
    # max = ceil((pop_total/k) * (1 + pop_threshold))



    # pops, pop_eval = district.pop_summary(individual)
    #print(pops.sum()/k)
    #print(pops)
    #print(pop_eval)
    #print((50*(1-(pops/pop_target)**(-pop_eval))).astype("int"))
    # adjusted = district.pop_repair(individual)
    #
    # np.savetxt("../data/demo_solutions/adj2.csv", adjusted, fmt="%i")

    # for i in range(78, 101):
    #     print(i)
    #     individual = district.initial(k)
    #     adjusted = district.pop_repair(individual)
    #     np.savetxt("../data/demo_solutions/solution_%s.csv" % i, adjusted, fmt="%i")

    #print(district.pop_summary(individual))
    #np.savetxt("../data/demo_solutions/solution_%s.csv" % i, individual, fmt="%i")
    # print("Compactness: %s" % district.compactness(individual))
    # print("Vote Efficiency: %s" % district.vote_efficiency_gap(individual))
    # print("Cluster Score: %s" % district.cluster_proximity("all_cluster", individual))


if __name__ == "__main__":
    main()