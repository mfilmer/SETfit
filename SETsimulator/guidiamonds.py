#!/usr/bin/python
# -*- coding: utf-8 -*-

"""
    Example 1
    Single electron transistor with a dot in the orthodox model

    Mathieu Pierre - january 2009
    modif Benoit Roche - aout 2011, BV and XJ - nov 2012
"""

"""
    Modified by Michael McConnell - September 2014
"""

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

def IVg(myset, T, Vg_start, Vg_end, Ng, Vd, filename=0):
    """Compute the current for a sweep in gate voltage
       Vg,I,P = IVg(myset, T, Vg_start, Vg_end, step, Vd, filename)
       Inputs :
           myset    : instance of SET class
           T        : temperature (K)
           Vg_start : initial value for the gate voltage (mV)
           Vg_end   : final value for the gate voltage (mV)
           Ng       : number of points
           Vd       : drain bias (mV) - the source is grounded
           filename : optional - if provided data will appened to that file
       Outputs :
           Vg : gate voltage
           I  : current between drain and dot
           P  : mean occupation of the dot
    """
    myset.set_temperature(T)
    myset.pre_processing()
    Vg = scipy.linspace(Vg_start, Vg_end, Ng)
    I = []
    P = []
    for vg in Vg:
        myset.tunnel_rate([0, Vd, vg])    
        myset.solver() 
        I.append(myset.current('drain', 'dot'))
        P.append(myset.proba('dot'))
    # convert lists to scipy arrays
    I = scipy.array(I)
    P = scipy.array(P)
    if filename != 0:
        data = create_array(Vg,I,P)
        # convert from a scipy 2D array to a list of lines
        data = map(list,list(data)) 
        write_file(data,filename)
    return Vg, I, P

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

def create_array(*V):
    """Take a finite number of python lists or numpy 1D arrays
    and put them in columns into a 2D array.
    They must have the same length.
    """
    data = scipy.zeros((len(V[0]),0))
    for v in V:
        v = scipy.array(v)
        v = v[:,scipy.newaxis]
        data = scipy.concatenate((data,v),1)
    return data

def plot_1D(x, y, params):
    glog = params['glog']
    gmax = params['gmax']
    if gmax is None:
        gmax = y.max()
    
    if params['neg_conductance']:
        y = abs(y)
    if glog is not None:
        matplotlib.pyplot.semilogy(x, y, '.k')
        matplotlib.pyplot.semilogy(x, y, '-k')
        gmin=glog
        matplotlib.pyplot.axis(ymin=gmin, ymax=gmax)
    else:
        matplotlib.pyplot.plot(x, y, '.k')
        matplotlib.pyplot.plot(x, y, '-k')
        gmin=-gmax
        matplotlib.pyplot.axis('tight')
    
    if params['xlabel'] is None:
        params['xlabel'] = params['var1_name']
    if params['ylabel'] is None:
        params['ylabel'] = params['data_label']
    matplotlib.pyplot.xlabel(params['xlabel'])
    matplotlib.pyplot.ylabel(params['ylabel'])

def plot_2D(data_matrix, X, Y):
    # Plot configuration
    params = ReadData.rhombus.get_default_config()
    params['xlabel'] = 'Vg (mV)'
    params['ylabel'] = 'Vd (mV)'
    params['gsym'] = True
    params['glog'] = None
    params['colorbar_display'] = True
    params['axes'] = None
    
    print len(X), len(Y), X[0], X[-1], Y[0], Y[-1]
    a = ReadData.rhombus.Data(data_matrix, len(X), len(Y), X[0], X[-1], Y[0], Y[-1])
    ReadData.rhombus.plot_bis(a, params)

if __name__ == "__main__": 
    Tinput=float(sys.argv[1])
    vds_start=float(sys.argv[2])
    vds_end=float(sys.argv[3])
    numVdspoints=int(sys.argv[4])
    Cs=float(sys.argv[5])
    Cd=float(sys.argv[6])
    Gs=float(sys.argv[7])
    Gd=float(sys.argv[8])
    num_e=int(sys.argv[9])
    vg_start=float(sys.argv[10])
    vg_end=float(sys.argv[11])
    numVgpoints=int(sys.argv[12])
    Cg=float(sys.argv[13])
    
    
    if len(sys.argv)==14:
        data_matrix, X, Y = diamond(Tinput, vg_start, vg_end, numVgpoints, vds_start, vds_end, numVdspoints, Cs, Cd, Cg, Gs, Gd, num_e, mode='difcon', dVg=False)
    else:
        print "Error: not enough command line arguments"
