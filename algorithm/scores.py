import numpy as np
import pandas as pd
from math import pi


def perimeter(data, adjacency, edges, solution):
    #perimeters = np.zeros(len(np.unique(solution))+1)
    perimeters = pd.Series(np.zeros(len(np.unique(solution))), index=np.unique(solution))
    for i, row in enumerate(adjacency.rows):
        ai = solution[i]
        perimeters[ai] += data.iloc[i]["outer_edge"]
        for j in row:
            aj = int(data.iloc[j]["assignment"])
            if i < j and ai != aj:
                perimeters[ai] += edges[i, j]
                perimeters[aj] += edges[i, j]

    return perimeters


def compactness(data, adjacency, edges, solution):
    districts = np.unique(solution)
    perimeters = perimeter(data, adjacency, edges, solution)
    areas = data["area"].groupby(solution).sum()
    scores = 4*pi*areas/(perimeters**2)
    return scores.mean()