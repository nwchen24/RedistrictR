#This file contains functions for the evaluation of a given district assignment.
#Functions included are a function to measure vote efficiency gap and a function to measure cluster purity
#The input to the evaluation functions is a dataframe of each block group and a list containing the district assignment for each block group.
#The cluster purity evaluation function also requires the name of the clustering method variable to be evaluated for purity. The options are 'all_cluster' or 'racial_demographic_cluster'

import pandas as pd
import numpy as np



#***************************************************************************
#Cluster Purity Function
#***************************************************************************
def cluster_purity_calc(df, cluster_var, assignment_list):

    #add assignment list as a column
    df['district_assignment'] = assignment_list

    grouped_by_dist = df[['district_assignment', cluster_var]].groupby(by=['district_assignment', cluster_var]).size()

    #format the dataframe
    grouped_by_dist = grouped_by_dist.reset_index(name = 'counts')
    grouped_by_dist.columns = grouped_by_dist.columns.get_level_values(0)

    #reshape to wide
    grouped_by_dist = grouped_by_dist.pivot(index='district_assignment', columns='all_cluster', values='counts')

    #reset column names
    grouped_by_dist = grouped_by_dist.reset_index()
    grouped_by_dist.columns = grouped_by_dist.columns.get_level_values(0)

    #subset columns
    grouped_by_dist = grouped_by_dist[['district_assignment', 1, 2, 3, 4, 5]]

    #replace NA with zero
    grouped_by_dist = grouped_by_dist.fillna(value = 0)

    #Get total number of block groups in each district
    grouped_by_dist['total_blockgroups'] = grouped_by_dist[1] + grouped_by_dist[2] + grouped_by_dist[3] + grouped_by_dist[4] + grouped_by_dist[5]

    #Get share of each district acounted for by block groups in each cluster
    grouped_by_dist['cluster_1_share'] = grouped_by_dist[1] / grouped_by_dist['total_blockgroups']
    grouped_by_dist['cluster_2_share'] = grouped_by_dist[2] / grouped_by_dist['total_blockgroups']
    grouped_by_dist['cluster_3_share'] = grouped_by_dist[3] / grouped_by_dist['total_blockgroups']
    grouped_by_dist['cluster_4_share'] = grouped_by_dist[4] / grouped_by_dist['total_blockgroups']
    grouped_by_dist['cluster_5_share'] = grouped_by_dist[5] / grouped_by_dist['total_blockgroups']

    #get the max purity for each district
    grouped_by_dist['max_purity'] = grouped_by_dist[['cluster_1_share', 'cluster_2_share', 'cluster_3_share', 'cluster_4_share', 'cluster_5_share']].max(axis = 1)

    return np.mean(grouped_by_dist['max_purity'])


#***************************************************************************
#Vote Efficiency Gap Function
#***************************************************************************
def vote_efficiency_gap_calc(df,assignment_list):
    
    #add assignment list as a column
    df['district_assignment'] = assignment_list
    
    grouped_by_dist = df[['district_assignment', 'Dem_votes_Pres_08', 'Rep_votes_Pres_08']].groupby(by=['district_assignment']).agg(['sum'])

    #format the dataframe
    grouped_by_dist = grouped_by_dist.reset_index()
    grouped_by_dist.columns = grouped_by_dist.columns.get_level_values(0)

    #get winner for each district
    grouped_by_dist['winner'] = np.where(grouped_by_dist['Dem_votes_Pres_08'] > grouped_by_dist['Rep_votes_Pres_08'], 'Dem', 'Rep')

    #get wasted democratic and replublican votes (i.e. votes above the winning threshold)
    grouped_by_dist['dem_wasted'] = np.where(grouped_by_dist['winner'] == 'Dem', grouped_by_dist['Dem_votes_Pres_08'] - grouped_by_dist['Rep_votes_Pres_08'], 0)
    grouped_by_dist['rep_wasted'] = np.where(grouped_by_dist['winner'] == 'Rep', grouped_by_dist['Rep_votes_Pres_08'] - grouped_by_dist['Dem_votes_Pres_08'], 0)

    #get total wasted votes for each party
    dem_wasted_votes = np.sum(grouped_by_dist['dem_wasted'])
    rep_wasted_votes = np.sum(grouped_by_dist['rep_wasted'])

    #Calculate efficiency gap and efficiency gap percentage
    efficiency_gap = abs(dem_wasted_votes - rep_wasted_votes)
    efficiency_gap_pct = efficiency_gap / (np.sum(grouped_by_dist['Dem_votes_Pres_08']) +  np.sum(grouped_by_dist['Rep_votes_Pres_08']))

    del df['district_assignment']
    
    return(efficiency_gap_pct)


#***************************************************************************
#Unit Integrity Function
#***************************************************************************
def unit_integrity_calc(df, assignment_list):

    df['assignment'] = assignment_list
    
    #*************************************
    #Tract penalty
    #Penalize one point for each tract that is split up
    #This penalty has a max value of 1 and a min value of zero if no tract is split up
    #*************************************
    
    #get total number of block groups in each tract
    groupedby_tract = pd.DataFrame(df.groupby(by=['TRACTCE']).size())
    groupedby_tract = groupedby_tract.reset_index()
    groupedby_tract.columns = ['TRACTCE', 'TOTAL_blockgroups']

    #group by tract and assignment and count the number of block groups in each tract that end up in each assignment
    groupedby_tract_assignment = pd.DataFrame(df.groupby(by=['TRACTCE', 'assignment']).size())
    groupedby_tract_assignment = groupedby_tract_assignment.reset_index()
    groupedby_tract_assignment.columns = ['TRACTCE', 'assignment', 'num_blockgroups']

    #merge total number of block groups in each tract with the grouped by tract and assignment
    groupedby_tract_assignment = pd.merge(groupedby_tract, groupedby_tract_assignment)

    #flag tracts that are split up
    groupedby_tract_assignment['flag_split_tract'] = np.where(groupedby_tract_assignment['num_blockgroups'] != groupedby_tract_assignment['TOTAL_blockgroups'], 1, 0)

    tract_penalty = np.mean(groupedby_tract_assignment['flag_split_tract'])

    #*************************************
    #Place penalty
    #Penalize one point for a place that is split into two districts, two points for a place that is split into three districts, etc.
    #This penalty has a max value of 1 and a min value of zero if no place is split up
    #*************************************

    #group by place and asignment
    grouped_by_place_assignment = pd.DataFrame(df.groupby(by=['PLACEFP', 'assignment']).size())
    grouped_by_place_assignment = grouped_by_place_assignment.reset_index()
    grouped_by_place_assignment.columns = ['PLACEFP', 'assignment', 'count_of_blockgroups']
    grouped_by_place_assignment.head()

    #group by place to get the number of districts into which each place is split
    grouped_by_place = pd.DataFrame(grouped_by_place_assignment.groupby(by = ['PLACEFP']).size())
    grouped_by_place = grouped_by_place.reset_index()
    grouped_by_place.columns = ['PLACEFP', 'count_of_districts']

    #Penalize
    #0 points if the place is in one district, 1 point if it is in 2 districts, 2 points if it is in 3 districts, etc.
    grouped_by_place['penalty'] = grouped_by_place.count_of_districts - 1

    #Get total penalty
    place_penalty = float(np.sum(grouped_by_place.penalty)) / (float(grouped_by_place.shape[0]) * 10 )
    
    return tract_penalty + place_penalty

