#CONTROL DATA
LFeasCut = false
LFeasPerStage = false
LCostApprox = true
LCostApproxNewCuts = true
LWindStoch = false
LDemandResponse = false
LExtreme = false
MaxIter = 2
CCMaxIter = 1
MaxIterWCC = 5
ConvEps = 1.0E-3
NScen = 30
NWindScen = 5
NScenSim = 30
NBranch = 10 #changed to fix loaderror  NResIdRead != NResid in inflow model for hydrocen data #7
NStage = 3*52
NStageSim =2*52
LNewInflowModel = false
ResInitFrac = 0.60
ResMinFrac = 0.10
MaxResScale = 1.0
LoadScale = 1.0
LineCapScale = 1.0
CapReqFrac = 0.10
H2CompLoss = 0.10
CTR = ReSDDP.Control(LFeasCut,LFeasPerStage,LCostApprox,LCostApproxNewCuts,LWindStoch,LDemandResponse,LExtreme,MaxIter,CCMaxIter,MaxIterWCC,ConvEps,NScen,
                     NWindScen,NScenSim,NBranch,NStage,NStageSim,ResInitFrac,ResMinFrac,MaxResScale,LoadScale,LineCapScale,CapReqFrac,H2CompLoss)

#AGGREGATION DATA
ModCutoff = 7
ResCutoff = 25000000000.0
ProdCutoff = 25000000000.0
DeplCutoff = 0.0
RegDegCutoff = 0.5
CAGR = ReSDDP.Aggregation(ModCutoff,ResCutoff,ProdCutoff,DeplCutoff,RegDegCutoff) 

#HORIZON AND TIME RESOLUTION
NSecHour = 3600.0
NHoursWeek = 168.0
NInflowYear = 30 #50 (4del), 30 (Norge), 58 (Hydrocen), 30 (HydroConnect)
NWeek = 52  #Dimensioning factor
NK = 56  #Time steps per week
DT = NHoursWeek/Float64(NK)
WeekFrac = 1.0/Float64(NK)
CTI = ReSDDP.Time(NSecHour,NHoursWeek,NInflowYear,NWeek,NK,DT,WeekFrac)

#CONSTANTS
MAGEFF2GWH = 1.0E3/NSecHour #Convert MM3*m3/s to GWh/week; Mm3*eta*C = GWh, then C=hours/10E3 sec
GWH2MAGEFF = NSecHour/1.0E3
MW2GWHWEEK = NHoursWeek/1000.0
MW2GW = 1.0E-3
M3S2MM3 = 3.6E-3
CEnPen = 1.0
CResPen = 1.0
CRampPen = 1.0
CCapPen = 1.0
CAuxPen = 10.0
CSpi = 2.0E-3
CByp = 1.0E-3
CNegRes = 1.0E4
CMinRes = 5.0
CRat = 4.0E2
CFeas = 1.0E2
Big = 1.0E16
AlphaMax = 1E18
InfUB = 1.0E08
FeasTol = 1.0E-3
CNS = ReSDDP.Constants(MAGEFF2GWH,GWH2MAGEFF,MW2GWHWEEK,MW2GW,M3S2MM3,CEnPen,CResPen,CRampPen,CCapPen,CAuxPen,CSpi,CByp,CNegRes,CMinRes,CRat,CFeas,Big,AlphaMax,InfUB,FeasTol)

#DISCRETIZATION OF FEASIBILITY SPACES
NInfPt = 5 
NResInitPt = 5
NResEndPt = 5
NEnPt = 5
NRampPt = 5
NCapPt = 2
CDI = ReSDDP.Discrete(NInfPt,NResInitPt,NResEndPt,NEnPt,NRampPt,NCapPt)

parameters = ReSDDP.Parameters(CTR, CAGR, CTI, CNS, CDI)
