// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>

#pragma once

#include <nlohmann/json_fwd.hpp>

#include "Model.hpp"

namespace cdm {

void to_json(nlohmann::ordered_json& j, const Model::Input& p);

void from_json(const nlohmann::ordered_json& j, Model::Input& p);

} // namespace cdm