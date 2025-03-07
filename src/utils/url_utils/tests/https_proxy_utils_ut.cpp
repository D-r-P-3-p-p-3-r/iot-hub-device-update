/**
 * @file https_proxy_utils_ut.cpp
 * @brief Unit Tests for https_proxy_utils library
 *
 * @copyright Copyright (c) Microsoft Corporation.
 * Licensed under the MIT License.
 */
#include "aduc/https_proxy_utils.h"
#include <catch2/catch_all.hpp>

using Catch::Matchers::Equals;

#include <aducpal/stdlib.h> // setenv, unsetenv

class TestCaseFixture
{
public:
    TestCaseFixture()
    {
        const char* proxy;

        proxy = getenv("https_proxy");
        if (proxy != nullptr)
        {
            existing_https_proxy = proxy;
        }
        ADUCPAL_unsetenv("https_proxy");
#if !defined(WIN32)
        proxy = getenv("HTTPS_PROXY");
        if (proxy != nullptr)
        {
            existing_HTTPS_PROXY = proxy;
        }
        ADUCPAL_unsetenv("HTTPS_PROXY");
#endif
    }

    ~TestCaseFixture()
    {
        if (!existing_https_proxy.empty())
        {
            ADUCPAL_setenv("https_proxy", existing_https_proxy.c_str(), 1);
        }
        else
        {
            ADUCPAL_unsetenv("https_proxy");
        }

#if !defined(WIN32)
        if (!existing_HTTPS_PROXY.empty())
        {
            ADUCPAL_setenv("HTTPS_PROXY", existing_HTTPS_PROXY.c_str(), 1);
        }
        else
        {
            ADUCPAL_unsetenv("HTTPS_PROXY");
        }
#endif
    }

    TestCaseFixture(const TestCaseFixture&) = delete;
    TestCaseFixture& operator=(const TestCaseFixture&) = delete;
    TestCaseFixture(TestCaseFixture&&) = delete;
    TestCaseFixture& operator=(TestCaseFixture&&) = delete;

private:
    std::string existing_https_proxy;
#if !defined(WIN32)
    // Windows environment variables aren't case sensitive.
    std::string existing_HTTPS_PROXY;
#endif
};

TEST_CASE_METHOD(TestCaseFixture, "Parse https_proxy (escaped)")
{
    ADUCPAL_setenv(
        "https_proxy",
        "http://%75%73%65%72%6E%61%6De:update%3B%2F%3F%3A%40%26%3D%2B%24%2C@%65x%61%6D%70%6C%65%2E%63%6F%6D:8888",
        1);

    HTTP_PROXY_OPTIONS proxyOptions = {};
    bool proxyOk = InitializeProxyOptions(&proxyOptions);
    CHECK(proxyOk);
    CHECK_THAT(proxyOptions.host_address, Equals("example.com"));
    CHECK(proxyOptions.port == 8888);
    CHECK_THAT(proxyOptions.username, Equals("username"));
    CHECK_THAT(proxyOptions.password, Equals("update;/?:@&=+$,"));
    UninitializeProxyOptions(&proxyOptions);
}

TEST_CASE_METHOD(TestCaseFixture, "Parse https_proxy")
{
    ADUCPAL_setenv("https_proxy", "http://127.0.0.1:8888", 1);

    HTTP_PROXY_OPTIONS proxyOptions = {};
    bool proxyOk = InitializeProxyOptions(&proxyOptions);
    CHECK(proxyOk);
    CHECK_THAT(proxyOptions.host_address, Equals("127.0.0.1"));
    CHECK(proxyOptions.port == 8888);
    CHECK(proxyOptions.username == nullptr);
    CHECK(proxyOptions.password == nullptr);
    UninitializeProxyOptions(&proxyOptions);
}

TEST_CASE_METHOD(TestCaseFixture, "Parse HTTPS_PROXY (uppper case)")
{
    ADUCPAL_setenv("HTTPS_PROXY", "http://127.0.0.1:123", 1);

    HTTP_PROXY_OPTIONS proxyOptions = {};
    bool proxyOk = InitializeProxyOptions(&proxyOptions);
    CHECK(proxyOk);
    CHECK_THAT(proxyOptions.host_address, Equals("127.0.0.1"));
    CHECK(proxyOptions.port == 123);
    CHECK(proxyOptions.username == nullptr);
    CHECK(proxyOptions.password == nullptr);
    UninitializeProxyOptions(&proxyOptions);
}

// If both https_proxy and HTTPS_PROXY exist, use https_proxy.
TEST_CASE_METHOD(TestCaseFixture, "Use https_proxy (lower case)")
{
    // Put uppercase first, so that on OS where env is case-insensitive (e.g. Windows)
    // the second will overwrite the first.
    ADUCPAL_setenv("HTTPS_PROXY", "http://222.0.0.1:123", 1);
    ADUCPAL_setenv("https_proxy", "http://127.0.0.1:8888", 1);

    HTTP_PROXY_OPTIONS proxyOptions = {};
    bool proxyOk = InitializeProxyOptions(&proxyOptions);
    CHECK(proxyOk);
    CHECK_THAT(proxyOptions.host_address, Equals("127.0.0.1"));
    CHECK(proxyOptions.port == 8888);
    CHECK(proxyOptions.username == nullptr);
    CHECK(proxyOptions.password == nullptr);
    UninitializeProxyOptions(&proxyOptions);
}

TEST_CASE_METHOD(TestCaseFixture, "Parse username and password")
{
    ADUCPAL_setenv("https_proxy", "http://username:password@127.0.0.1:8888", 1);

    HTTP_PROXY_OPTIONS proxyOptions = {};
    bool proxyOk = InitializeProxyOptions(&proxyOptions);
    CHECK(proxyOk);
    CHECK_THAT(proxyOptions.host_address, Equals("127.0.0.1"));
    CHECK(proxyOptions.port == 8888);
    CHECK_THAT(proxyOptions.username, Equals("username"));
    CHECK_THAT(proxyOptions.password, Equals("password"));
    UninitializeProxyOptions(&proxyOptions);
}

TEST_CASE_METHOD(TestCaseFixture, "No port number")
{
    ADUCPAL_setenv("https_proxy", "http://username:password@127.0.0.1", 1);

    HTTP_PROXY_OPTIONS proxyOptions = {};
    bool proxyOk = InitializeProxyOptions(&proxyOptions);
    CHECK(proxyOk);
    CHECK_THAT(proxyOptions.host_address, Equals("127.0.0.1"));
    CHECK(proxyOptions.port == 0);
    CHECK_THAT(proxyOptions.username, Equals("username"));
    CHECK_THAT(proxyOptions.password, Equals("password"));
    UninitializeProxyOptions(&proxyOptions);
}

TEST_CASE_METHOD(TestCaseFixture, "Empty username")
{
    ADUCPAL_setenv("https_proxy", "http://:password@127.0.0.1", 1);

    HTTP_PROXY_OPTIONS proxyOptions = {};
    bool proxyOk = InitializeProxyOptions(&proxyOptions);
    CHECK(proxyOk);
    CHECK_THAT(proxyOptions.host_address, Equals("127.0.0.1"));
    CHECK(proxyOptions.port == 0);
    CHECK(proxyOptions.username == nullptr);
    CHECK_THAT(proxyOptions.password, Equals("password"));
    UninitializeProxyOptions(&proxyOptions);
}

TEST_CASE_METHOD(TestCaseFixture, "Empty password (supported)")
{
    ADUCPAL_setenv("https_proxy", "http://username:@127.0.0.1:8888", 1);

    HTTP_PROXY_OPTIONS proxyOptions = {};
    bool proxyOk = InitializeProxyOptions(&proxyOptions);
    CHECK(proxyOk);
    CHECK_THAT(proxyOptions.host_address, Equals("127.0.0.1"));
    CHECK(proxyOptions.port == 8888);
    CHECK_THAT(proxyOptions.username, Equals("username"));
    CHECK(proxyOptions.password == nullptr);
    UninitializeProxyOptions(&proxyOptions);
}
