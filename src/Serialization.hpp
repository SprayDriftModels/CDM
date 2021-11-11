// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>

#pragma once

#include <memory>

#include <nlohmann/json_fwd.hpp>

#include "Model.hpp"
#include "DropletSizeModel.hpp"

namespace cdm {

void to_json(nlohmann::ordered_json& json, const std::unique_ptr<DropletSizeModel>& p);

void to_json(nlohmann::ordered_json& json, const Model& m);

void from_json(const nlohmann::ordered_json& json, Model& m);

} // namespace cdm