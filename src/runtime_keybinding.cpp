#include "runtime_keybinding.h"

#include <map>
#include <ranges>
#include <utility>
#include <vector>

namespace cata::runtime_keybindings
{
namespace
{
struct binding_key {
    std::string context;
    std::string action_id;

    auto operator<=>( const binding_key & ) const = default; // *NOPAD*
};

struct registry_state {
    std::map<std::string, std::map<std::string, registered_action>> actions_by_context;
    std::map<std::string, std::vector<binding_key>> source_index;
};

auto registry() -> registry_state & // *NOPAD*
{
    static auto state = registry_state {};
    return state;
}
} // namespace

auto register_action( const registration_options &opts ) -> void
{
    if( opts.source.empty() || opts.action_id.empty() || opts.context.empty() ) {
        return;
    }

    auto &state = registry();
    auto key = binding_key{ .context = opts.context, .action_id = opts.action_id };
    auto &source_entries = state.source_index[opts.source];
    if( !std::ranges::contains( source_entries, key ) ) {
        source_entries.push_back( key );
    }

    state.actions_by_context[opts.context][opts.action_id] = registered_action{
        .source = opts.source,
        .action_id = opts.action_id,
        .context = opts.context,
        .attributes = opts.attributes,
    };
}

auto clear_source( const std::string &source ) -> void
{
    auto &state = registry();
    const auto source_it = state.source_index.find( source );
    if( source_it == state.source_index.end() ) {
        return;
    }

    for( const auto &key : source_it->second ) {
        const auto context_it = state.actions_by_context.find( key.context );
        if( context_it == state.actions_by_context.end() ) {
            continue;
        }

        context_it->second.erase( key.action_id );
        if( context_it->second.empty() ) {
            state.actions_by_context.erase( context_it );
        }
    }

    state.source_index.erase( source_it );
}

auto find_action( const std::string &action_id,
                  const std::string &context ) -> const registered_action * // *NOPAD*
{
    const auto &state = registry();
    const auto context_it = state.actions_by_context.find( context );
    if( context_it == state.actions_by_context.end() ) {
        return nullptr;
    }

    const auto action_it = context_it->second.find( action_id );
    if( action_it == context_it->second.end() ) {
        return nullptr;
    }

    return &action_it->second;
}

auto find_any_action( const std::string &action_id ) -> const registered_action * // *NOPAD*
{
    const auto &state = registry();
    for( const auto &context_actions : state.actions_by_context | std::views::values ) {
        const auto action_it = context_actions.find( action_id );
        if( action_it != context_actions.end() ) {
            return &action_it->second;
        }
    }

    return nullptr;
}

auto get_registered_action_ids( const std::string &context ) -> std::vector<std::string>
{
    const auto &state = registry();
    const auto context_it = state.actions_by_context.find( context );
    if( context_it == state.actions_by_context.end() ) {
        return {};
    }

    return context_it->second
           | std::views::keys
           | std::ranges::to<std::vector>();
}
} // namespace cata::runtime_keybindings