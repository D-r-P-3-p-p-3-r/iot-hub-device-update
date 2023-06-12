/**
 * @file root_key_signing_key_utils_ut.cpp
 * @brief Unit Tests for disabled signing keys in the root_key_utils library
 *
 * @copyright Copyright (c) Microsoft Corporation.
 * Licensed under the MIT License.
 */

#include "root_key_util.h"
#include <aduc/string_handle_wrapper.hpp>
#include <azure_c_shared_utility/constbuffer.h>
#include <catch2/catch.hpp>

using Catch::Matchers::Equals;

TEST_CASE("RootKeyUtility_IsSigningKeyDisallowed")
{
    // ADUC_Result RootKeyUtility_IsSigningKeyDisallowed(
    //     const char* payload_alg,
    //     const CONSTBUFFER payload_hashPublicKeySigningKey,
    //     bool* is_signing_key_disallowed);
}

// Format of JWK payload:
// {
//     "kty": "RSA",
//     "alg": "RS256",
//     "kid": "ADU.210609.R.S"
//     "n": "<URLUInt encoded bytes>",
//     "e": "AQAB",
// }
const char[] decodedSigningKeyPayload =
    R"( {                            )"
    R"(     "kty": "RSA",            )"
    R"(     "alg": "RS256",          )"
    R"(     "kid": "ADU.201609.R.S", )"
    R"(       "e": "AQAB",           )"
    R"(       "n": "lLfsKo8Ytbcc2Q3N50UtLIfWQLVSAEbch+F/ce7S1YrJhXOSrzSfCnLpUiqPTw4zX/tiArAEuy7DAeUnEHEcx7Nkwwy5/8zKejvcEXpAJ/e3BKG4E4onfHQEpOsxwOKEeG0Gv9wWL3zTcNvdKXODXF3UPeJ1oGbPQms2zmCJxBbtSIYItmvicx2ekdVzWFw/vKTNuKk8hqK7HRfjOUKuKXyc+yHQI0aFBr2zkk3xh1tEOK98WJfxbcjPsDO6gzYzkXzCMza0O0GibBgLATT9Mf8YPpYG2jvOaDUoCQn2UcURNdl8hJbyjnZo2Jr+U84yuqOk7F4ZySoBv4bXJH2ZRRZFh/uSlsV9wRmYhYrv91DZiqk8HR6DSlnfneu28FThEmmosUM3k2YLsBc4Boupt3yaH8YnJT74u33uz19/MzTujKg7Tai12+XbtnZD9jTGayJtlhFeW+HC57AtAFZhqYwyGkX+83AaPXZ4a1O8u23NUGu2Ap7oM1N0yBJ+IlOz", )"
    R"( }                            )";

unsigned char pubKey[] = {
    0x30, 0x82, 0x01, 0xa2, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00,
    0x03, 0x82, 0x01, 0x8f, 0x00, 0x30, 0x82, 0x01, 0x8a, 0x02, 0x82, 0x01, 0x81, 0x00, 0x94, 0xb7, 0xec, 0x2a, 0x8f,
    0x18, 0xb5, 0xb7, 0x1c, 0xd9, 0x0d, 0xcd, 0xe7, 0x45, 0x2d, 0x2c, 0x87, 0xd6, 0x40, 0xb5, 0x52, 0x00, 0x46, 0xdc,
    0x87, 0xe1, 0x7f, 0x71, 0xee, 0xd2, 0xd5, 0x8a, 0xc9, 0x85, 0x73, 0x92, 0xaf, 0x34, 0x9f, 0x0a, 0x72, 0xe9, 0x52,
    0x2a, 0x8f, 0x4f, 0x0e, 0x33, 0x5f, 0xfb, 0x62, 0x02, 0xb0, 0x04, 0xbb, 0x2e, 0xc3, 0x01, 0xe5, 0x27, 0x10, 0x71,
    0x1c, 0xc7, 0xb3, 0x64, 0xc3, 0x0c, 0xb9, 0xff, 0xcc, 0xca, 0x7a, 0x3b, 0xdc, 0x11, 0x7a, 0x40, 0x27, 0xf7, 0xb7,
    0x04, 0xa1, 0xb8, 0x13, 0x8a, 0x27, 0x7c, 0x74, 0x04, 0xa4, 0xeb, 0x31, 0xc0, 0xe2, 0x84, 0x78, 0x6d, 0x06, 0xbf,
    0xdc, 0x16, 0x2f, 0x7c, 0xd3, 0x70, 0xdb, 0xdd, 0x29, 0x73, 0x83, 0x5c, 0x5d, 0xd4, 0x3d, 0xe2, 0x75, 0xa0, 0x66,
    0xcf, 0x42, 0x6b, 0x36, 0xce, 0x60, 0x89, 0xc4, 0x16, 0xed, 0x48, 0x86, 0x08, 0xb6, 0x6b, 0xe2, 0x73, 0x1d, 0x9e,
    0x91, 0xd5, 0x73, 0x58, 0x5c, 0x3f, 0xbc, 0xa4, 0xcd, 0xb8, 0xa9, 0x3c, 0x86, 0xa2, 0xbb, 0x1d, 0x17, 0xe3, 0x39,
    0x42, 0xae, 0x29, 0x7c, 0x9c, 0xfb, 0x21, 0xd0, 0x23, 0x46, 0x85, 0x06, 0xbd, 0xb3, 0x92, 0x4d, 0xf1, 0x87, 0x5b,
    0x44, 0x38, 0xaf, 0x7c, 0x58, 0x97, 0xf1, 0x6d, 0xc8, 0xcf, 0xb0, 0x33, 0xba, 0x83, 0x36, 0x33, 0x91, 0x7c, 0xc2,
    0x33, 0x36, 0xb4, 0x3b, 0x41, 0xa2, 0x6c, 0x18, 0x0b, 0x01, 0x34, 0xfd, 0x31, 0xff, 0x18, 0x3e, 0x96, 0x06, 0xda,
    0x3b, 0xce, 0x68, 0x35, 0x28, 0x09, 0x09, 0xf6, 0x51, 0xc5, 0x11, 0x35, 0xd9, 0x7c, 0x84, 0x96, 0xf2, 0x8e, 0x76,
    0x68, 0xd8, 0x9a, 0xfe, 0x53, 0xce, 0x32, 0xba, 0xa3, 0xa4, 0xec, 0x5e, 0x19, 0xc9, 0x2a, 0x01, 0xbf, 0x86, 0xd7,
    0x24, 0x7d, 0x99, 0x45, 0x16, 0x45, 0x87, 0xfb, 0x92, 0x96, 0xc5, 0x7d, 0xc1, 0x19, 0x98, 0x85, 0x8a, 0xef, 0xf7,
    0x50, 0xd9, 0x8a, 0xa9, 0x3c, 0x1d, 0x1e, 0x83, 0x4a, 0x59, 0xdf, 0x9d, 0xeb, 0xb6, 0xf0, 0x54, 0xe1, 0x12, 0x69,
    0xa8, 0xb1, 0x43, 0x37, 0x93, 0x66, 0x0b, 0xb0, 0x17, 0x38, 0x06, 0x8b, 0xa9, 0xb7, 0x7c, 0x9a, 0x1f, 0xc6, 0x27,
    0x25, 0x3e, 0xf8, 0xbb, 0x7d, 0xee, 0xcf, 0x5f, 0x7f, 0x33, 0x34, 0xee, 0x8c, 0xa8, 0x3b, 0x4d, 0xa8, 0xb5, 0xdb,
    0xe5, 0xdb, 0xb6, 0x76, 0x43, 0xf6, 0x34, 0xc6, 0x6b, 0x22, 0x6d, 0x96, 0x11, 0x5e, 0x5b, 0xe1, 0xc2, 0xe7, 0xb0,
    0x2d, 0x00, 0x56, 0x61, 0xa9, 0x8c, 0x32, 0x1a, 0x45, 0xfe, 0xf3, 0x70, 0x1a, 0x3d, 0x76, 0x78, 0x6b, 0x53, 0xbc,
    0xbb, 0x6d, 0xcd, 0x50, 0x6b, 0xb6, 0x02, 0x9e, 0xe8, 0x33, 0x53, 0x74, 0xc8, 0x12, 0x7e, 0x22, 0x53, 0xb3, 0x02,
    0x03, 0x01, 0x00, 0x01
};

bool matches_pubkey(const CONSTBUFFER* buf)
{
    if (buf->size != sizeof(pubKey))
    {
        return false;
    }

    for (int i = 0; i < buf->size; ++i)
    {
        if (buf->buffer[i] != pubKey[i])
        {
            return false;
        }
    }

    return true;
}

TEST_CASE("RootKeyUtility_GetAlgAndPublicKeyHashSigningKeyFromSigningKeyPayload")
{
    char* hashAlg = nullptr;
    ADUC::StringUtils::STRING_HANDLE_wrapper signingKeyIdentityHashAlg{};
    CONSTBUFFER_HANDLE publicKeyHashIdentity = nullptr;

    ADUC_Result result = RootKeyUtility_GetAlgAndPublicKeyHashSigningKeyFromSigningKeyPayload(
        decodedSigningKeyPayload, signingKeyIdentityHashAlg.address_of(), &publicKeyHashIdentity);

    REQUIRE(IsAducResultCodeSuccess(result.ResultCode));
    REQUIRE_FALSE(signingKeyIdentityHashAlg.is_null());
    CHECK_THAT(signingKeyIdentityHashAlg.c_str(), Equals("SHA256"));
    CHECK(matches_pubkey(CONSTBUFFER_GetContent(publicKeyHashIdentity)));

    if (publicKeyHashIdentity != nullptr)
    {
        CONSTBUFFER_DecRef(publicKeyHashIdentity);
        publicKeyHashIdentity = nullptr;
    }
}
