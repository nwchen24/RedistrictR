from scipy.sparse import csr_matrix, lil_matrix
from scipy.io import mmread
import pandas as pd


def loadData(name):
    """Load the block data, adjacency matrix and adjacent edge matrix."""
    data = pd.read_csv("../data/"+name+"_data.csv")
    adjacency = lil_matrix(mmread("../data/"+name+"_adjacency.mtx"))
    edges = csr_matrix(mmread("../data/"+name+"_edges.mtx"))

    return data, adjacency, edges


