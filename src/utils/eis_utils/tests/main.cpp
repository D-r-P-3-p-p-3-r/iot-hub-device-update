/**
 * @file main.cpp
 * @brief crypto_utils tests main entry point.
 *
 * @copyright Copyright (c) Microsoft Corporation.
 * Licensed under the MIT License.
 */
// https://github.com/catchorg/Catch2/blob/master/docs/own-main.md
#include <catch2/catch_session.hpp>

// https://github.com/Azure/umock-c/blob/master/doc/umock_c.md
#include <umock_c/umock_c.h>

#include <ostream>
#include <iostream>

int main(int argc, char* argv[])
{
    int result;

    // Global setup
    result = umock_c_init([](UMOCK_C_ERROR_CODE error_code) -> void {
        std::cerr << "*** umock_c failed, err=" << error_code << std::endl;
    });
    if (result != 0)
    {
        std::cerr << "umock_c_init_failed, err=" << result << std::endl;
        return result;
    }

    result = Catch::Session().run(argc, argv);

    // Global cleanup.
    umock_c_deinit();

    return result;
}
