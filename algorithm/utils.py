from scipy.sparse import csr_matrix, lil_matrix
from scipy.io import mmread
import pandas as pd
from sys import argv


def loadData(name):
    """Load the block data, adjacency matrix and adjacent edge matrix."""
    data = pd.read_csv("../data/"+name+"_data.csv")
    adjacency = lil_matrix(mmread("../data/"+name+"_adjacency.mtx"))
    edges = csr_matrix(mmread("../data/"+name+"_edges.mtx"))
    qadjacency = lil_matrix(mmread("../data/"+name+"_qadjacency.mtx"))

    return data, adjacency, edges, qadjacency


#helper function to parse comand line args
def getopts(argv):
    opts = {}  # Empty dictionary to store key-value pairs.
    while argv:  # While there are arguments left to parse...
        if argv[0][0] == '-':  # Found a "-name value" pair.
            opts[argv[0]] = argv[1]  # Add key and value to the dictionary.
        argv = argv[1:]  # Reduce the argument list by copying it starting from index 1.
    return opts