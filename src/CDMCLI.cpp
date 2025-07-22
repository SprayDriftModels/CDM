#include <chrono>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>

#include <fmt/core.h>

#include "CDM.h"
#include "CLI11.hpp"

int main(int argc, char *argv[])
{
    std::string infile, outfile;
    bool verbose = false;
    
    CLI::App app("Casanova Drift Model");
    app.set_version_flag("--version", "cdm version " CDM_VERSION_STRING);
    app.add_option("-i,--input,input", infile, "Read configuration from FILE")
        ->option_text("FILE")
        ->required()
        ->capture_default_str()
        ->check(CLI::ExistingFile);
    app.add_option("-o,--output", outfile, "Write output to FILE")
        ->option_text("FILE");
    app.add_flag("-v, --verbose", verbose, "Enable verbose output");
    app.preparse_callback([](std::size_t arity) {
        if (arity == 0) throw CLI::CallForHelp(); });
    
    CLI11_PARSE(app, argc, argv);

    std::ifstream ifs;
    std::stringstream buffer;
    ifs.exceptions(std::ios_base::failbit | std::ios_base::badbit);
    try {
        ifs.open(infile);
        buffer << ifs.rdbuf();
        ifs.close();
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

    if (!outfile.empty()) {
        std::ofstream ofs;
        try {
            ofs.open(outfile);
            char *out = cdm_get_output_string(model);
            ofs << std::string(out);
            ofs.close();
            cdm_free_string(out);
        } catch (std::exception& e) {
            fmt::print("{}\n", e.what());
            return 1;
        }
    }
    
    cdm_free_model(model);
    
    auto end = std::chrono::steady_clock::now();
    fmt::print("\nElapsed: {} ms\n", std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count());

    return 0;
}
