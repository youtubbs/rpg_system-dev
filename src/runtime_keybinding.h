#pragma once

#include <string>

#include "input.h"

namespace cata::runtime_keybindings
{
struct registered_action {
    std::string source;
    std::string action_id;
    std::string context;
    action_attributes attributes;
};

struct registration_options {
    std::string source;
    std::string action_id;
    std::string context = "default";
    action_attributes attributes;
};

auto register_action( const registration_options &opts ) -> void;
auto clear_source( const std::string &source ) -> void;
auto find_action( const std::string &action_id,
                  const std::string &context ) -> const registered_action *; // *NOPAD*
auto find_any_action( const std::string &action_id ) -> const registered_action *; // *NOPAD*
auto get_registered_action_ids( const std::string &context ) -> std::vector<std::string>;
} // namespace cata::runtime_keybindings