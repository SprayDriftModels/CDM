#include <chrono>
#include <iostream>
#include <fstream>
#include <sstream>
#include <string>

#include <fmt/core.h>

#include "CDM.h"

int main(int argc, char *argv[])
{
    const std::string filename = argc > 1 ? argv[1] : "config.json";

    std::ifstream ifs;
    std::stringstream buffer;

    ifs.exceptions(std::ios_base::failbit | std::ios_base::badbit);
    
    try {
        ifs.open(filename);
        buffer << ifs.rdbuf();
    } catch (std::exception& e) {
        fmt::print("{}\n", e.what());
        return 1;
    }
    
    auto start = std::chrono::steady_clock::now();

    cdm_model_t *model = cdm_create_model(buffer.str().c_str());
    
    int rc = cdm_run_model(model);
    if (rc != 0) {
        cdm_free_model(model);
        return 1;
    }

    cdm_print_report(model);

    cdm_free_model(model);

    auto end = std::chrono::steady_clock::now();
    fmt::print("\nElapsed: {} ms\n", std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count());
    
    return 0;
}
