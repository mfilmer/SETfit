#!/usr/bin/python
# -*- coding: utf-8 -*-

try:
    import scipy
except ImportError:
    raise ImportError, 'Please install Python-Scipy. http://www.scipy.org/'

from scipy import *
import set
import sys
import ReadData
import matplotlib.pyplot


def system(Vg, Cs, Cd, Cg, Gs, Gd, num_e):
    """returns an instance of the SET class"""
    myset = set.SET()
    # choose between the two lines below for metallic dot or quantum levels
    myset.add_metallic_dot('dot', num_e, -num_e, 0)
    #myset.add_quantum_dot('dot', [0, 1, 2, 3], [1, 1, 1, 1])
    myset.add_lead('source')
    myset.add_lead('drain')
    myset.add_gate('gate')
    #myset.add_link('dl', 'dot', 'source', 5.5e-18, 0.2)
    #myset.add_link('dl', 'dot', 'drain', 5.5e-18, 0.2)
    myset.add_link('dl', 'dot', 'drain', Cd,Gd)
    myset.add_link('dl', 'dot', 'source', Cs, Gs)
    #myset.add_link('dl', 'dot', 'drain', 1e-19, 10e-8)
    #myset.add_link('dl', 'dot', 'drain', Cg, Gg)
    myset.add_link('dg', 'dot', 'gate', Cg)
    return myset

def derive(F, X):
    return scipy.diff(F)/abs(X[1]-X[0]), linspace(X[0], X[-1], len(X)-1)

def diamond(T, Vg_start, Vg_end, Ng, Vd_start, Vd_end, Nd, Cs, Cd, Cg, Gs, Gd, num_e, mode='difcon', dVg=False, filename='simData.dat'):
    """Compute the current or transconductance for a sweep in Vg and Vd
       Inputs :
           myset    : instance of SET class
           T        : temperature (K)
           Vg_start : initial value for the gate voltage (mV)
           Vg_end   : final value for the gate voltage (mV)
           Ng       : number of points
           Vd_start : initial value for the drain voltage (mV)
           Vd_end   : final value for the drain voltage (mV)
           Nd       : number of points
           mode     : 'current' or 'transconductance'
           filename : data will appened to that file
    """
    Vg = scipy.linspace(Vg_start, Vg_end, Ng)
    Vd = scipy.linspace(Vd_start, Vd_end, Nd)
    data_matrix = []
    for (i_vg, vg) in enumerate(Vg):
        myset=system(vg, Cs, Cd, Cg, Gs, Gd, num_e)
        myset.set_temperature(T)
        myset.pre_processing()
        I = []
        P = []
        V_dot = []
        print "Vg = ", vg
        for vd in Vd:
            myset.tunnel_rate([0, vd, vg])    
            myset.solver() 
            I.append(myset.current('drain','dot'))
            P.append(myset.proba('dot'))
            V_dot.append(myset.voltage('dot'))
        # convert lists to scipy arrays
        I = scipy.array(I)
        P = scipy.array(P)
        V_dot = scipy.array(V_dot)
        # compute the diffential conductance
        if mode == 'current':
            Y = Vd
            F = I
        elif mode == 'difcon':
            F, Y = derive(I, Vd)
            F *= 1e3
        elif mode == 'voltage':
            Y = Vd
            F = V_dot
        elif mode == 'francis':
            F_1, Y = derive(I, Vd)
            F_2, Y = derive(Vd-V_dot, Vd)
            F = F_1/F_2
            F *= 1e3
        elif mode == 'sourcis':
            F_1, Y = derive(I, Vd)
            F_2, Y = derive(V_dot, Vd)
            F = F_1/F_2
            F *= 1e3
        data_matrix.append(F)
    data_matrix = array(data_matrix)
    data_matrix = transpose(data_matrix)
    X = Vg
    
    # Derivate with Vg
    if dVg:
        data_dVg = []
        for vd_i in arange(len(Y)):
            F_dVg, X_dVg = derive(data_matrix[vd_i,:], X)
            F_dVg *= 1e3
            data_dVg.append(F_dVg)
        data_matrix = array(data_dVg)
        X = X_dVg
    
    if filename != 0: 
        write_file(data_matrix, filename)
    return data_matrix, X, Y

def write_file(data,filename):
    f = open(filename,'w')
    for y in range(data.shape[0]):
        for x in range(data.shape[1]):
            if x != 0:
                f.write('\t')
            f.write('%.6g' % (data[y,x],))
        f.write('\n')
    f.close()

if __name__ == "__main__": 
    Tinput = float(sys.argv[1])
    vds_start = float(sys.argv[2])
    vds_end = float(sys.argv[3])
    numVdspoints = int(sys.argv[4])
    Cs = float(sys.argv[5])
    Cd = float(sys.argv[6])
    Gs = float(sys.argv[7])
    Gd = float(sys.argv[8])
    num_e = int(sys.argv[9])
    vg_start = float(sys.argv[10])
    vg_end = float(sys.argv[11])
    numVgpoints = int(sys.argv[12])
    Cg = float(sys.argv[13])
    savefile = sys.argv[14]
    
    
    if len(sys.argv) == 15:
        data_matrix, X, Y = diamond(Tinput, vg_start, vg_end, numVgpoints, vds_start, vds_end, numVdspoints, Cs, Cd, Cg, Gs, Gd, num_e, mode='difcon', dVg=False, filename=savefile)
    else:
        print "Error: Wrong number of command line arguments"
