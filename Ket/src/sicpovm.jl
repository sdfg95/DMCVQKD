function shift_operator(d::Integer; T::Type = Float64)
    X = zeros(Complex{T}, d, d)
    for i = 0:d-1
        X[mod(i + 1, d)+1, i+1] = Complex{T}(1)
    end
    return X
end
export shift_operator

function clock_operator(d::Integer; T::Type = Float64)
    R = Complex{T}
    z = zeros(R, d)
    z[1] = R(1)
    for i = 1:d-1
        if 4 * i == d
            z[i+1] = R(im)
        elseif 2 * i == d
            z[i+1] = R(-1)
        elseif 4 * i == 3 * d
            z[i+1] = R(-im)
        else
            z[i+1] = exp(im * 2 * T(π) * i / d)
        end
    end
    return LA.Diagonal(z)
end
export clock_operator

function sic_povm(d; T::Type = Float64)
    fiducial = _fiducial_WH(d; T)
    vecs = Vector{Vector{Complex{T}}}(undef, d^2)
    for p = 0:d-1
        Xp = shift_operator(d; T)^p
        for q = 0:d-1
            Zq = clock_operator(d; T)^q
            vecs[d*p+q+1] = Xp * Zq * fiducial
        end
    end
    for vi in vecs
        vi ./= sqrt(T(d)) * LA.norm(vi)
    end
    return vecs
end
export sic_povm

function test_sic(vecs::Vector{Vector{Complex{T}}}) where {T<:Real}
    d = length(vecs[1])
    m = zeros(T, d^2, d^2)
    for j = 1:d^2
        for i = 1:j
            m[i, j] = abs2(vecs[i]' * vecs[j])
        end
    end
    display(m)
    is_normalized = LA.diag(m) ≈ T(1) / d^2 * ones(d^2)
    is_uniform = LA.triu(m, 1) ≈ (1 / T(d^2 * (d + 1))) * LA.triu(ones(d^2, d^2), 1)
    return is_normalized && is_uniform
end
export test_sic

function dilate_povm(vecs::Vector{Vector{R}}) where {R<:Union{Real,Complex}}
    d = length(vecs[1])
    V = zeros(R, d^2, d)
    for i = 1:d^2
        V[i, :] = vecs[i]'
    end
    return V
end
export dilate_povm

function dilate_povm(E::Vector{<:AbstractMatrix})
    n = length(E)
    d = size(E[1], 1)
    rtE = sqrt.(E)
    return V = sum(kron(rtE[i], ket(i, n)) for i = 1:n)
end

"""Computes the fiducial Weyl-Heisenberg vector of dimension `d`

Reference: Appleby, Yadsan-Appleby, Zauner, http://arxiv.org/abs/1209.1813 http://www.gerhardzauner.at/sicfiducials.html
"""
function _fiducial_WH(d::Integer; T::Type = Float64)
    maxd = 7
    a = zeros(T, maxd)
    r = zeros(T, maxd, 4)
    t = zeros(T, maxd)
    b = zeros(Complex{T}, maxd, 4)

    a[4] = sqrt(T(5))
    r[4, 1] = sqrt(T(2))
    b[4, 1] = im * sqrt(a[4] + 1)

    a[5] = sqrt(T(3))
    r[5, 1] = sqrt(T(5))
    t[5] = sin(T(π) / 5)
    b[5, 1] = im * sqrt(5a[5] + (5 + 3r[5, 1]) * t[5])

    a[6] = sqrt(T(21))
    r[6, 1] = sqrt(T(2))
    r[6, 2] = sqrt(T(3))
    b[6, 1] = im * sqrt(2a[6] + 6)
    b[6, 2] = 2real((1 + im * sqrt(T(7)))^(1 // 3))

    a[7] = sqrt(T(2))
    r[7, 1] = sqrt(T(7))
    t[7] = cos(T(π) / 7)
    b[7, 1] = im * sqrt(2a[7] + 1)

    all_fiducials = [
        [T(1)],
        [sqrt(0.5 * (1 + 1 / sqrt(T(3)))), exp(im * T(π) / 4) * sqrt(0.5 * (1 - 1 / sqrt(T(3))))],
        [T(0), T(1), T(1)],
        [
            T(1) / 40 * (-a[4] + 5) * r[4, 1] + T(1) / 20 * (-a[4] + 5),
            ((-T(1) / 40 * a[4] * r[4, 1] - T(1) / 40 * a[4]) * b[4, 1] + (T(1) / 80 * (a[4] - 5) * r[4, 1] + T(1) / 40 * (a[4] - 5))) * im +
            -T(1) / 40 * a[4] * b[4, 1] +
            T(1) / 80 * (-a[4] + 5) * r[4, 1],
            T(1) / 40 * (a[4] - 5) * r[4, 1] * im,
            ((T(1) / 40 * a[4] * r[4, 1] + T(1) / 40 * a[4]) * b[4, 1] + (T(1) / 80 * (a[4] - 5) * r[4, 1] + T(1) / 40 * (a[4] - 5))) * im +
            T(1) / 40 * a[4] * b[4, 1] +
            T(1) / 80 * (-a[4] + 5) * r[4, 1],
        ],
        [
            T(1) / 60 * (-a[5] + 3) * r[5, 1] + T(1) / 12 * (-a[5] + 3),
            (
                ((T(1) / 120 * a[5] * r[5, 1] + T(1) / 40 * a[5]) * t[5] + (-T(1) / 240 * a[5] * r[5, 1] + T(1) / 240 * a[5])) * b[5, 1] +
                (T(1) / 120 * (a[5] - 3) * r[5, 1] * t[5] + (T(1) / 32 * (-a[5] + 1) * r[5, 1] + T(1) / 32 * (-a[5] + 1)))
            ) * im +
            ((-T(1) / 120 * a[5] * r[5, 1] - T(1) / 120 * a[5]) * t[5] - T(1) / 120 * a[5]) * b[5, 1] +
            T(1) / 40 * (a[5] - 1) * r[5, 1] * t[5] +
            T(1) / 160 * (-a[5] + 3) * r[5, 1] +
            T(1) / 96 * (a[5] - 3),
            (
                ((-T(1) / 80 * a[5] * r[5, 1] + T(1) / 240 * (-7 * a[5] + 6)) * t[5] + (T(1) / 480 * (-a[5] + 9) * r[5, 1] + T(1) / 480 * (-a[5] + 15))) * b[5, 1] +
                (T(1) / 120 * (-a[5] + 3) * r[5, 1] * t[5] + (T(1) / 32 * (-a[5] + 1) * r[5, 1] + T(1) / 32 * (-a[5] + 1)))
            ) * im +
            ((T(1) / 240 * (2 * a[5] + 3) * r[5, 1] + T(1) / 240 * (4 * a[5] + 3)) * t[5] + (T(1) / 480 * (-a[5] - 3) * r[5, 1] + T(1) / 160 * (-a[5] - 5))) * b[5, 1] +
            T(1) / 40 * (-a[5] + 1) * r[5, 1] * t[5] +
            T(1) / 160 * (-a[5] + 3) * r[5, 1] +
            T(1) / 96 * (a[5] - 3),
            (
                ((T(1) / 80 * a[5] * r[5, 1] + T(1) / 240 * (7 * a[5] - 6)) * t[5] + (T(1) / 480 * (a[5] - 9) * r[5, 1] + T(1) / 480 * (a[5] - 15))) * b[5, 1] +
                (T(1) / 120 * (-a[5] + 3) * r[5, 1] * t[5] + (T(1) / 32 * (-a[5] + 1) * r[5, 1] + T(1) / 32 * (-a[5] + 1)))
            ) * im +
            ((T(1) / 240 * (-2 * a[5] - 3) * r[5, 1] + T(1) / 240 * (-4 * a[5] - 3)) * t[5] + (T(1) / 480 * (a[5] + 3) * r[5, 1] + T(1) / 160 * (a[5] + 5))) * b[5, 1] +
            T(1) / 40 * (-a[5] + 1) * r[5, 1] * t[5] +
            T(1) / 160 * (-a[5] + 3) * r[5, 1] +
            T(1) / 96 * (a[5] - 3),
            (
                ((-T(1) / 120 * a[5] * r[5, 1] - T(1) / 40 * a[5]) * t[5] + (T(1) / 240 * a[5] * r[5, 1] - T(1) / 240 * a[5])) * b[5, 1] +
                (T(1) / 120 * (a[5] - 3) * r[5, 1] * t[5] + (T(1) / 32 * (-a[5] + 1) * r[5, 1] + T(1) / 32 * (-a[5] + 1)))
            ) * im +
            ((T(1) / 120 * a[5] * r[5, 1] + T(1) / 120 * a[5]) * t[5] + T(1) / 120 * a[5]) * b[5, 1] +
            T(1) / 40 * (a[5] - 1) * r[5, 1] * t[5] +
            T(1) / 160 * (-a[5] + 3) * r[5, 1] +
            T(1) / 96 * (a[5] - 3),
        ],
        [
            (T(1) / 1008 * (-a[6] + 3) * r[6, 2] * b[6, 1] * b[6, 2]^2 + T(1) / 504 * (a[6] - 6) * r[6, 2] * b[6, 1] * b[6, 2] + (T(1) / 168 * (a[6] - 2) * r[6, 2] - T(1) / 168 * a[6]) * b[6, 1]) * im +
            T(1) / 504 * (-a[6] + 5) * r[6, 2] * b[6, 2]^2 +
            T(1) / 504 * (a[6] + 1) * r[6, 2] * b[6, 2] +
            T(1) / 504 * (-a[6] - 13) * r[6, 2] +
            T(1) / 168 * (a[6] + 21),
            (
                (T(1) / 2016 * (-a[6] + 3) * r[6, 2] * b[6, 1] + (T(1) / 504 * (a[6] - 7) * r[6, 2] + T(1) / 336 * (a[6] - 5))) * b[6, 2]^2 +
                ((T(1) / 1008 * (a[6] - 6) * r[6, 2] + T(1) / 672 * (-a[6] + 7)) * b[6, 1] + (T(1) / 1008 * (-a[6] - 7) * r[6, 2] + T(1) / 336 * (-a[6] - 1))) * b[6, 2] +
                ((T(1) / 672 * (a[6] + 3) * r[6, 2] + T(1) / 672 * (-3 * a[6] + 7)) * b[6, 1] + (T(1) / 504 * (-3 * a[6] + 14) * r[6, 2] + T(1) / 168 * (-a[6] - 4)))
            ) * im +
            ((T(1) / 1008 * (-a[6] + 3) * r[6, 2] + T(1) / 672 * (a[6] - 3)) * b[6, 1] + (T(1) / 1008 * (-3 * a[6] + 7) * r[6, 2] - T(1) / 84)) * b[6, 2]^2 +
            ((T(1) / 2016 * (a[6] - 3) * r[6, 2] - T(1) / 336) * b[6, 1] + (T(1) / 1008 * (5 * a[6] - 7) * r[6, 2] + T(1) / 336 * (a[6] - 5))) * b[6, 2] +
            (T(1) / 224 * (a[6] - 5) * r[6, 2] + T(1) / 672 * (-7 * a[6] + 19)) * b[6, 1] +
            T(1) / 72 * (a[6] - 4) * r[6, 2] +
            T(1) / 168 * (-a[6] + 22),
            (
                (T(1) / 672 * (-a[6] + 3) * r[6, 2] * b[6, 1] + T(1) / 336 * (a[6] - 5)) * b[6, 2]^2 +
                (T(1) / 336 * r[6, 2] * b[6, 1] + T(1) / 336 * (-a[6] - 1)) * b[6, 2] +
                ((T(1) / 672 * (5 * a[6] - 19) * r[6, 2] + T(1) / 224 * (-a[6] + 7)) * b[6, 1] + (T(1) / 336 * (5 * a[6] - 21) * r[6, 2] + T(1) / 336 * (-5 * a[6] + 13)))
            ) * im +
            (T(1) / 672 * (-a[6] + 3) * b[6, 1] + T(1) / 1008 * (a[6] - 5) * r[6, 2]) * b[6, 2]^2 +
            (T(1) / 336 * b[6, 1] + T(1) / 1008 * (-a[6] - 1) * r[6, 2]) * b[6, 2] +
            (T(1) / 672 * (-a[6] + 7) * r[6, 2] + T(1) / 672 * (5 * a[6] - 19)) * b[6, 1] +
            T(1) / 1008 * (-5 * a[6] + 13) * r[6, 2] +
            T(1) / 336 * (5 * a[6] - 21),
            (
                (T(1) / 504 * (a[6] - 3) * r[6, 2] * b[6, 1] + T(1) / 504 * (a[6] - 1) * r[6, 2]) * b[6, 2]^2 +
                (T(1) / 1008 * (-a[6] + 3) * r[6, 2] * b[6, 1] + T(1) / 252 * (-a[6] + 2) * r[6, 2]) * b[6, 2] +
                (T(1) / 168 * (-a[6] + 4) * r[6, 2] * b[6, 1] + T(1) / 504 * (-9 * a[6] + 11) * r[6, 2])
            ) * im +
            (T(1) / 1008 * (a[6] - 3) * r[6, 2] * b[6, 1] - T(1) / 126 * r[6, 2]) * b[6, 2]^2 +
            (T(1) / 1008 * (a[6] - 9) * r[6, 2] * b[6, 1] + T(1) / 504 * (a[6] - 5) * r[6, 2]) * b[6, 2] +
            T(1) / 168 * (-a[6] + 2) * r[6, 2] * b[6, 1] +
            T(1) / 504 * (-5 * a[6] + 23) * r[6, 2],
            (
                (T(1) / 2016 * (-a[6] + 3) * r[6, 2] * b[6, 1] + T(1) / 336 * (-a[6] + 1)) * b[6, 2]^2 +
                (T(1) / 2016 * (-a[6] + 9) * r[6, 2] * b[6, 1] + T(1) / 168 * (a[6] - 2)) * b[6, 2] +
                ((T(1) / 672 * (a[6] + 3) * r[6, 2] + T(1) / 672 * (a[6] - 21)) * b[6, 1] + (T(1) / 168 * a[6] * r[6, 2] + T(1) / 168 * (3 * a[6] - 16)))
            ) * im +
            (T(1) / 672 * (-a[6] + 3) * b[6, 1] + T(1) / 1008 * (a[6] + 7) * r[6, 2]) * b[6, 2]^2 +
            (T(1) / 672 * (a[6] - 5) * b[6, 1] + T(1) / 504 * (-2 * a[6] + 7) * r[6, 2]) * b[6, 2] +
            (T(1) / 672 * (3 * a[6] - 7) * r[6, 2] + T(1) / 672 * (a[6] - 5)) * b[6, 1] +
            T(1) / 504 * (-a[6] - 28) * r[6, 2] +
            T(1) / 168 * a[6],
            (
                (T(1) / 672 * (a[6] - 3) * b[6, 1] + (T(1) / 1008 * (-a[6] + 1) * r[6, 2] + T(1) / 84)) * b[6, 2]^2 +
                ((T(1) / 672 * (a[6] - 7) * r[6, 2] + T(1) / 672 * (-a[6] + 5)) * b[6, 1] + (T(1) / 504 * (a[6] - 2) * r[6, 2] + T(1) / 336 * (-a[6] + 5))) * b[6, 2] +
                ((T(1) / 672 * (a[6] - 7) * r[6, 2] + T(1) / 672 * (-3 * a[6] + 5)) * b[6, 1] + (T(1) / 1008 * (3 * a[6] - 11) * r[6, 2] + T(1) / 336 * (-a[6] - 23)))
            ) * im +
            (T(1) / 672 * (-a[6] + 3) * r[6, 2] * b[6, 1] + (T(1) / 252 * r[6, 2] + T(1) / 336 * (a[6] - 1))) * b[6, 2]^2 +
            ((T(1) / 672 * (a[6] - 5) * r[6, 2] + T(1) / 672 * (a[6] - 7)) * b[6, 1] + (T(1) / 1008 * (-a[6] + 5) * r[6, 2] + T(1) / 168 * (-a[6] + 2))) * b[6, 2] +
            (T(1) / 672 * (3 * a[6] - 5) * r[6, 2] + T(1) / 672 * (a[6] - 7)) * b[6, 1] +
            T(1) / 1008 * (-a[6] - 23) * r[6, 2] +
            T(1) / 336 * (-3 * a[6] + 11),
        ],
        [
            T(1) / 14 * (a[7] + 1),
            (
                (T(1) / 196 * (a[7] - 4) * r[7, 1] * t[7]^2 + T(1) / 392 * (3 * a[7] + 2) * r[7, 1] * t[7] + T(1) / 392 * (a[7] + 3) * r[7, 1]) * b[7, 1] +
                (T(1) / 196 * (a[7] + 6) * r[7, 1] * t[7]^2 + T(1) / 392 * (-3 * a[7] - 4) * r[7, 1] * t[7] + T(1) / 392 * (-5 * a[7] - 9) * r[7, 1])
            ) * im +
            (-T(1) / 28 * a[7] * t[7]^2 + T(1) / 56 * (a[7] - 2) * t[7] + T(1) / 56 * (a[7] - 1)) * b[7, 1] +
            T(1) / 28 * (3 * a[7] + 6) * t[7]^2 +
            T(1) / 56 * (-a[7] - 4) * t[7] +
            T(1) / 56 * (-3 * a[7] - 5),
            (
                (T(1) / 196 * (3 * a[7] + 2) * r[7, 1] * t[7]^2 + T(1) / 196 * (-2 * a[7] + 1) * r[7, 1] * t[7] + T(1) / 784 * (a[7] - 4) * r[7, 1]) * b[7, 1] +
                (T(1) / 196 * (-3 * a[7] - 4) * r[7, 1] * t[7]^2 + T(1) / 196 * (a[7] - 1) * r[7, 1] * t[7] + T(1) / 784 * (-5 * a[7] - 2) * r[7, 1])
            ) * im +
            (T(1) / 28 * (a[7] - 2) * t[7]^2 + T(1) / 28 * t[7] - T(1) / 112 * a[7]) * b[7, 1] +
            T(1) / 28 * (-a[7] - 4) * t[7]^2 +
            T(1) / 28 * (-a[7] - 1) * t[7] +
            T(1) / 112 * (a[7] + 6),
            (
                (T(1) / 98 * (2 * a[7] - 1) * r[7, 1] * t[7]^2 + T(1) / 392 * (-a[7] + 4) * r[7, 1] * t[7] + T(1) / 784 * (-11 * a[7] + 2) * r[7, 1]) * b[7, 1] +
                (T(1) / 98 * (a[7] - 1) * r[7, 1] * t[7]^2 + T(1) / 392 * (a[7] + 6) * r[7, 1] * t[7] + T(1) / 784 * (-13 * a[7] - 8) * r[7, 1])
            ) * im +
            (-T(1) / 14 * t[7]^2 + T(1) / 56 * a[7] * t[7] + T(1) / 112 * (-a[7] + 6)) * b[7, 1] +
            T(1) / 14 * (-a[7] - 1) * t[7]^2 +
            T(1) / 56 * (3 * a[7] + 6) * t[7] +
            T(1) / 112 * a[7],
            (
                (T(1) / 98 * (-2 * a[7] + 1) * r[7, 1] * t[7]^2 + T(1) / 392 * (a[7] - 4) * r[7, 1] * t[7] + T(1) / 784 * (11 * a[7] - 2) * r[7, 1]) * b[7, 1] +
                (T(1) / 98 * (a[7] - 1) * r[7, 1] * t[7]^2 + T(1) / 392 * (a[7] + 6) * r[7, 1] * t[7] + T(1) / 784 * (-13 * a[7] - 8) * r[7, 1])
            ) * im +
            (T(1) / 14 * t[7]^2 - T(1) / 56 * a[7] * t[7] + T(1) / 112 * (a[7] - 6)) * b[7, 1] +
            T(1) / 14 * (-a[7] - 1) * t[7]^2 +
            T(1) / 56 * (3 * a[7] + 6) * t[7] +
            T(1) / 112 * a[7],
            (
                (T(1) / 196 * (-3 * a[7] - 2) * r[7, 1] * t[7]^2 + T(1) / 196 * (2 * a[7] - 1) * r[7, 1] * t[7] + T(1) / 784 * (-a[7] + 4) * r[7, 1]) * b[7, 1] +
                (T(1) / 196 * (-3 * a[7] - 4) * r[7, 1] * t[7]^2 + T(1) / 196 * (a[7] - 1) * r[7, 1] * t[7] + T(1) / 784 * (-5 * a[7] - 2) * r[7, 1])
            ) * im +
            (T(1) / 28 * (-a[7] + 2) * t[7]^2 - T(1) / 28 * t[7] + T(1) / 112 * a[7]) * b[7, 1] +
            T(1) / 28 * (-a[7] - 4) * t[7]^2 +
            T(1) / 28 * (-a[7] - 1) * t[7] +
            T(1) / 112 * (a[7] + 6),
            (
                (T(1) / 196 * (-a[7] + 4) * r[7, 1] * t[7]^2 + T(1) / 392 * (-3 * a[7] - 2) * r[7, 1] * t[7] + T(1) / 392 * (-a[7] - 3) * r[7, 1]) * b[7, 1] +
                (T(1) / 196 * (a[7] + 6) * r[7, 1] * t[7]^2 + T(1) / 392 * (-3 * a[7] - 4) * r[7, 1] * t[7] + T(1) / 392 * (-5 * a[7] - 9) * r[7, 1])
            ) * im +
            (T(1) / 28 * a[7] * t[7]^2 + T(1) / 56 * (-a[7] + 2) * t[7] + T(1) / 56 * (-a[7] + 1)) * b[7, 1] +
            T(1) / 28 * (3 * a[7] + 6) * t[7]^2 +
            T(1) / 56 * (-a[7] - 4) * t[7] +
            T(1) / 56 * (-3 * a[7] - 5),
        ],
    ]
    return all_fiducials[d]
end
