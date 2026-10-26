#pragma once

#include <string>
#include <string_view>

namespace benchmark_service {

enum class UserType { kFirstTime, kKnown };

std::string SayHelloTo(std::string_view name, UserType type);

}  // namespace benchmark_service