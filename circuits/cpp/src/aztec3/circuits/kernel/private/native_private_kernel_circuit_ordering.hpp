#pragma once

#include "init.hpp"

#include "aztec3/circuits/abis/kernel_circuit_public_inputs.hpp"
#include "aztec3/circuits/abis/previous_kernel_data.hpp"
#include "aztec3/circuits/abis/read_request_membership_witness.hpp"
#include "aztec3/constants.hpp"
#include "aztec3/utils/circuit_errors.hpp"
#include "aztec3/utils/dummy_circuit_builder.hpp"

#include <array>

namespace aztec3::circuits::kernel::private_kernel {

using aztec3::circuits::abis::KernelCircuitPublicInputs;
using aztec3::circuits::abis::PreviousKernelData;
using DummyBuilder = aztec3::utils::DummyCircuitBuilder;
using aztec3::circuits::abis::ReadRequestMembershipWitness;
using aztec3::utils::CircuitResult;

KernelCircuitPublicInputs<NT> native_private_kernel_circuit_ordering(
    DummyBuilder& builder,
    PreviousKernelData<NT> const& previous_kernel,
    std::array<NT::fr, READ_REQUESTS_LENGTH> const& read_requests,
    std::array<abis::ReadRequestMembershipWitness<NT, PRIVATE_DATA_TREE_HEIGHT>, READ_REQUESTS_LENGTH> const&
        read_request_membership_witnesses);

CircuitResult<KernelCircuitPublicInputs<NT>> native_private_kernel_circuit_ordering_rr_dummy(
    PreviousKernelData<NT> const& previous_kernel);

}  // namespace aztec3::circuits::kernel::private_kernel