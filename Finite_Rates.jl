"""
The code is initiated via the function FiniteInstance(.).
"""


push!(LOAD_PATH,"Ket/")
using  Ket
using  SpecialFunctions
using  LinearAlgebra
using  DoubleFloats
using  JuMP
using  Parameters
using  Roots
using  Printf
import Hypatia
import Hypatia.Cones
import Convex
import Integrals

include("Utils_FKRates.jl")


@with_kw struct InputDual{T}
    p_τAB::Matrix{T}
    p_sim::Matrix{T}
    dim_p::Integer
    α    ::T
    D    ::Int
    ε    ::T
    PE_AB::Vector{Matrix{Complex{T}}}
    Λ_AB ::Vector{Matrix{Complex{T}}}
    λ_A  ::Vector{T}
    ∇r::Hermitian{Complex{T},Matrix{Complex{T}}}
end

@with_kw struct OutputDual{T<:AbstractFloat}
    Dvars ::Array{T}
    MaxMin::T
    Rate  ::T
    Hba   ::T
end

@with_kw struct Epsilon_Coeffs{T<:AbstractFloat}
    ϵ    ::T
    ϵ_PE ::T
    ϵ_PA ::T
    ϵ_EC ::T
end

function FW_Dual_Pert(InDual::InputDual{T}) where {T<:AbstractFloat} 
    # Unpack all the required variables
    @unpack p_τAB,p_sim,dim_p,α,D,ε,PE_AB,Λ_AB,λ_A,∇r = InDual 
    
    # Prepare convex program
    Dual_FW = GenericModel{T}()
    set_optimizer(Dual_FW, Hypatia.Optimizer{T})

    # Set variables
    @variable(Dual_FW,y[1:dim_p])
    @variable(Dual_FW,w[1:dim_p+12])
    @variable(Dual_FW,z[1:12])

    # Semidef. constraint
    grad_dim = Cones.svec_length(Complex,size(∇r,1))
    grad_vec = Vector{GenericAffExpr{T, GenericVariableRef{T}}}(undef, grad_dim)    
    Cones._smat_to_svec_complex!(grad_vec, ∇r -sum(PE_AB.*y) -sum(Λ_AB.*z), sqrt(T(2)))
    @constraint(Dual_FW,grad_vec in Hypatia.PosSemidefTriCone{T,Complex{T}}(grad_dim))    

    # Constraints for the num error
    for jj=1:dim_p
        @constraint(Dual_FW,  y[jj]≤w[jj])
        @constraint(Dual_FW, -w[jj]≤y[jj])
    end

    for kk=1:12
        @constraint(Dual_FW, z[kk]≤w[dim_p+kk])
        @constraint(Dual_FW, -w[dim_p+kk]≤z[kk])
    end

    # Objective function
    @objective(Dual_FW,Max,y·p_sim'[:] + z·λ_A - ε*sum(w))

    # Perform optimization
    optimize!(Dual_FW)

    # Extract numerical values
    Y = value.(y)
    Z = value.(z)
    W = value.(w)

    MaxMin = maximum(Y) - minimum(Y)

    ObjVal = Y·p_sim'[:] + Z·λ_A - ε*sum(W)

    Hba  = EC_cost(α,D,0.0,T)
    Rate = ObjVal - Hba


    DualData = OutputDual(Y,MaxMin,Rate,Hba)
    return DualData
end


function Grad_ObjF(::Type{T},τAB::AbstractMatrix,dim_τAB::Integer) where {T}

    R  = BigFloat           # To improve the accuracy of the calculations
    Nc = Int((dim_τAB-4)/4) # Cutoff size

    # Calculate key maps
    G    = gkraus(T,Nc)
    Z    = zkraus(Nc)
    Zhat = [Zi*G for Zi in Z]

    # Apply channels
    τZ          = sum([Z*Complex{R}.(τAB)*Z' for Z in Zhat])
    λ_τZ, U_τZ  = eigen(Hermitian(τZ))
    Aux         = R(1e-20)*ones(length(λ_τZ)) # Small perturbation to ensure PSDness
    
    # Matrix logarithms
    log_τZ = Hermitian(sum([(Z'*U_τZ)*diagm(log2.(λ_τZ+Aux))*(Z'*U_τZ)' for Z in Zhat]))
    log_τ  = log(Hermitian(τAB))./log(T(2))

    # Final matrix gradient
    ∇r = Hermitian(log_τ-Complex{T}.(log_τZ))
    return ∇r
end


function FiniteKeyRate(N::T,Epsilons::Epsilon_Coeffs{T},InDual::InputDual{T},DualData::OutputDual{T}) where {T<:AbstractFloat}
    @unpack p_sim  = InDual
    @unpack Dvars  = DualData
    @unpack Rate   = DualData
    @unpack MaxMin = DualData
    @unpack Hba    = DualData
    @unpack ϵ,ϵ_PE,ϵ_PA,ϵ_EC = Epsilons

    # Quick Check
    if MaxMin ≥ 200 || Rate ≤ 0
        FKRate_Max = T(0)
        return FKRate_Max
    end


    #  Function Xi(x)
    if ϵ^2 < eps(T)
        # Linearization
        Ξ = -log2(0.5*ϵ^2)
    else
        Ξ = -log2(1-sqrt(1-ϵ^2))
    end

    dO = T(4+1) # Dimensions of the key output (4+⟂)

    ##############################
    # Grid search for the optimal scaling of the key rounds
    ##############################

    # Rough bounds for a
    aux   = N*Rate - 2*log2(1/ϵ_PA)
    a_min = (aux+Ξ)/(aux-log2(1/ϵ_PE))

    jj        = 0
    FKRateMax = T(0) 
    FKRate    = T(-1)
    stalling  = 0
    minval     = T(a_min-1)

    for scale=minval:minval/10:1
        a  = T(1+scale)
        jj+=1
        
        if mod(jj,5e5)==0
            @printf("Failure\n")
            return FKRateMax
        end

        
        A = log(T(2))*(a-1)/(4-2*a)     # Aux variable

        # Here we optimize the scaling b wrt the value of b
        F(b) = log(N)*(Rate*N^(-b) - A*MaxMin^2 *N^(b)*(sqrt(2+MaxMin^2 *N^b)
                +log2(2*dO^2 +1))/sqrt(2+MaxMin^2 *N^b)) - (Margin_tol(N,b,p_sim,Dvars,ϵ_PE,eps(T))-Margin_tol(N,b,p_sim,Dvars,ϵ_PE))/eps(T)
        b = find_zero(F, (0.0,0.5))

        #############

        Δ_tol = Margin_tol(N,b,p_sim,Dvars,ϵ_PE)

        # Finite-size corrections
        Zero = Rate*N^(-b) + Δ_tol

        # GEAT → V
        One = A*(sqrt(T(2)+ T(N^b) *MaxMin^2)+log2(2*dO^2+1))^2

        # GEAT → Ka
        K_exp = (a-1)*(2*log2(dO)+MaxMin)/(2-a)
        K_num = log(2^(2*log2(dO) + MaxMin) + exp(T(2)))^3 * 2^(K_exp)
        K_den = 6*log(T(2))*(3-2*a)^3
        Two   = (K_num*(2-a)*(a-1)^2)/K_den  

        # 2nd order correction
        Three = (2*log(1/ϵ_PA) + (Ξ+a*log2(1/ϵ_PE))/(a-1))/T(N)

        # Final key rate
        FKRate = Rate - Zero - One - Two - Three

        # Check the value of the finite key rate        
        if FKRate<FKRateMax
            # Convergence criterion - find the peak, and once it is
            # verified that it is the peak, break the simulation
            
            if FKRateMax>0
                stalling+=1
                if stalling>10
                    @printf("  Optimality reached: %.2e \n",FKRate)
                    # @printf("%.6e", FKRateMax) 
                    return FKRateMax
                end
            else
                stalling=0
            end
            continue
        else
            if mod(jj,150)==0
                @printf("Success at %.6e, %e \n",a-1,FKRate)
            end
            # Write the new optimal key rate 
            FKRateMax = FKRate
        end
    end
end


function Margin_tol(N::T,b::T,p_sim::Matrix{T},Dvars::Vector{T},ϵ_PE::T,dder_b=T(0.0)) where {T<:AbstractFloat}

    # Remark - note that the dual vars are assigned according  
    #          to a vector ordering p_sim'[:] for the primal
    Max = maximum(Dvars)
    Ppoint = p_sim'[:] 

    π_PE = [Ppoint*N^(-b-dder_b);1-sum(Ppoint)*N^(-b-dder_b)]
    h_PE = [-Max.+Dvars;0]*(N^(b+dder_b) -1)
    D_PE = abs(maximum(h_PE)-minimum(h_PE))

    # Tolerance margin for PE
    SumPE = 0
    for i=1:length(π_PE)-1
        gi = π_PE[i]*(1-sum(π_PE[1:i]))/(1-sum(π_PE[1:i-1]))
        ci = h_PE[i] - π_PE[i+1:end]'*h_PE[i+1:end]/(1-sum(π_PE[1:i]))
        SumPE += gi*ci^2
    end

    Δ_tol = 2*sqrt(log2(N/ϵ_PE)*SumPE/N) + 3*D_PE*log2(N/ϵ_PE)/N
    return Δ_tol

end


############### Suggested values for the input ###############
# T = Float64; N = T(5e8); δ = T(2.0); Δ = T(5.0); f = T(0.0); 
##############################################################

function FiniteInstance(N::Real,δ::Real,Δ::Real,f::Real,T::DataType=Float64)

    # Reassign data types if necessary
    N = T(N)
    δ = T(δ)
    Δ = T(Δ)
    f = T(f)

    # Epsilon coefficients (they hardly require any change)
    Epsilons = Epsilon_Coeffs(T(1e-10),T(1e-10),T(1e-10),T(1e-10))

    # Prepare file names
    NAME_RATE = "CPrimal_f"*string(Int(floor(f*100)))*"D"*string(Int(floor(Δ*10)))*"d"*string(Int(floor(δ*10)))*".csv"
    NAME_OUT  = "FKRates_f"*string(Int(floor(f*100)))*"D"*string(Int(floor(Δ*10)))*"d"*string(Int(floor(δ*10)))*".csv"

    # Prepare outputs
    FILE_OUT = open(NAME_OUT,"a")
    @printf(FILE_OUT,"N, D, amp, FKR \n")
    close(FILE_OUT)

    # Read input states
    FILE_STATES = open(NAME_RATE,"r")
    head        = readline(FILE_STATES) # Remove heading

    for k =1:40
        # Load next state
        Data = split(chop(readline(FILE_STATES); head=0, tail=0), ',')

        # Read data
        D   = parse(Int,Data[1])
        α   = parse(T,Data[2])
        τv  = parse.(T,Data[3:end])

        τAB     = Hmat(τv)              # Recompose the matrix
        dim_τAB = size(τAB,1)           # Get dimensions
        Nc      = Int((dim_τAB-4)/4)    # Get photon cutoff

        # Prepare the input by enforcing PSDness 
        #  XXX QUESTION ABOUT ConicQKD -- if the state at the output is neg. how do you compute the log??
        while eigmin(τAB) ≤ 0
            Aux = abs(eigmin(τAB))
            τAB .*= 1-Aux
            τAB .+= Aux*I(size(τAB,1))/size(τAB,1)
        end

        # Calculate and bound numerical error 
        p_τAB = constraint_probabilities(T,τAB,δ,Δ,Nc)
        p_sim = simulated_probabilities(T,δ,Δ,α,D)
        dim_p = length(p_sim[:])

        τA = Hermitian(Convex.partialtrace(T(1)*τAB, 2, [4, Nc+1]))

        Num_error1 = maximum(p_τAB-p_sim)
        Num_error2 = maximum(Hvec(τA-alice_part(α)))

        ε = maximum([Num_error1,Num_error2])
        @printf("Max. numerical error: %.6e \n",ε)

        # Calculate operators at the constraints
        PE_AB = constraint_operators(T,δ,Δ,Nc)

        # Get the tomography
        Λ_AB, λ_A = alice_tomography(T,α,Nc)

        # Calculate gradient
        ∇r = Grad_ObjF(T,τAB,dim_τAB)

        # Prepare input of FW dual
        InDual = InputDual(
            p_τAB,
            p_sim,
            dim_p,
            α,
            D,
            ε,
            PE_AB,
            Λ_AB,
            λ_A,
            ∇r
        )

        # Calculate linearized dual
        DualData = FW_Dual_Pert(InDual)

        # Calculate finite key
        FKR  = FiniteKeyRate(N,Epsilons,InDual,DualData)

        # Save results and proceed with next iteration
        FILE_OUT = open(NAME_OUT,"a")
        @printf(FILE_OUT,"%.2e, %d, %.2f, %.6e \n",N,D,α,FKR)
        close(FILE_OUT)
    end
    
    # Close file with data
    close(FILE_STATES)
end



