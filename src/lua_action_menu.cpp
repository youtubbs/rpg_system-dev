#include "lua_action_menu.h"

#include <algorithm>
#include <ranges>
#include <utility>

#include "catalua_impl.h"
#include "debug.h"
#include "input.h"
#include "runtime_keybinding.h"
#include "translations.h"

namespace cata::lua_action_menu
{
namespace
{
static const std::string runtime_keybinding_source = "lua_action_menu";
static const std::string gameplay_context_id = "DEFAULTMODE";

auto entries_storage() -> std::vector<entry> & // *NOPAD*
{
    static auto entries = std::vector<entry> {};
    return entries;
}

auto action_context_id_storage() -> const std::string & // *NOPAD*
{
    static const auto value = std::string{ "ACTION_MENU" };
    return value;
}

auto make_action_id( const std::string &entry_id ) -> std::string
{
    return string_format( "LUA_ACTION_MENU:%s", entry_id );
}

auto normalize_category( const std::string &category_id ) -> std::string
{
    return category_id.empty() ? std::string{ "misc" } :
           category_id;
}

auto parse_hotkey( const std::optional<std::string> &hotkey ) -> int
{
    if( !hotkey || hotkey->empty() ) {
        return -1;
    }

    const auto keycode = inp_mngr.get_keycode( *hotkey );
    if( keycode == 0 ) {
        debugmsg( "Lua action menu hotkey '%s' is not a known key name.", *hotkey );
        return -1;
    }

    return keycode;
}
} // namespace

auto input_context_id() -> const std::string & // *NOPAD*
{
    return action_context_id_storage();
}

auto register_entry( const entry_options &opts ) -> void
{
    if( opts.id.empty() ) {
        debugmsg( "Lua action menu entry id must not be empty." );
        return;
    }
    if( opts.fn == sol::lua_nil ) {
        debugmsg( "Lua action menu entry '%s' has no fn.", opts.id );
        return;
    }

    auto entry_name = opts.name.empty() ? opts.id : opts.name;
    const auto keycode = parse_hotkey( opts.hotkey );
    auto attributes = action_attributes{};
    attributes.name = no_translation( entry_name );
    if( keycode > 0 ) {
        attributes.input_events.emplace_back( keycode, input_event_t::keyboard );
    }

    auto new_entry = entry{
        .id = opts.id,
        .action_id = make_action_id( opts.id ),
        .name = std::move( entry_name ),
        .category_id = normalize_category( opts.category_id ),
        .fn = opts.fn,
    };

    // Check for conflicts if a hotkey was provided (exclude our own action to avoid self-conflict)
    if( keycode > 0 ) {
        const auto event = input_event( keycode, input_event_t::keyboard );
        const auto conflicts_default = inp_mngr.find_conflicts_with_event( event, gameplay_context_id,
                                       new_entry.action_id );
        const auto conflicts_menu = inp_mngr.find_conflicts_with_event( event, input_context_id(),
                                    new_entry.action_id );

        if( !conflicts_default.empty() ) {
            const auto hotkey_str = opts.hotkey.value_or( "" );
            debugmsg( "Action '%s' with hotkey '%s' conflicts with existing keybindings in DEFAULTMODE: %s",
                      opts.id, hotkey_str, conflicts_default );
        }
        if( !conflicts_menu.empty() ) {
            const auto hotkey_str = opts.hotkey.value_or( "" );
            debugmsg( "Action '%s' with hotkey '%s' conflicts with existing keybindings in ACTION_MENU: %s",
                      opts.id, hotkey_str, conflicts_menu );
        }
    }

    cata::runtime_keybindings::register_action( {
        .source = runtime_keybinding_source,
        .action_id = new_entry.action_id,
        .context = gameplay_context_id,
        .attributes = attributes,
    } );

    cata::runtime_keybindings::register_action( {
        .source = runtime_keybinding_source,
        .action_id = new_entry.action_id,
        .context = input_context_id(),
        .attributes = std::move( attributes ),
    } );

    auto &entries = entries_storage();
    auto existing = std::ranges::find( entries, opts.id, &entry::id );
    if( existing != entries.end() ) {
        *existing = std::move( new_entry );
        return;
    }
    entries.push_back( std::move( new_entry ) );
}

auto clear_entries() -> void
{
    cata::runtime_keybindings::clear_source( runtime_keybinding_source );
    entries_storage().clear();
}

auto get_entries() -> const std::vector<entry> & // *NOPAD*
{
    return entries_storage();
}

auto run_entry( const std::string &id ) -> bool
{
    auto &entries = entries_storage();
    auto match = std::ranges::find( entries, id, &entry::id );
    if( match == entries.end() ) {
        debugmsg( "Lua action menu entry '%s' not found.", id );
        return false;
    }

    try {
        auto res = match->fn();
        check_func_result( res );
    } catch( const std::runtime_error &err ) {
        debugmsg( "Failed to run lua action menu entry '%s': %s", id, err.what() );
        return false;
    }

    return true;
}

auto run_action( const std::string &action_id ) -> bool
{
    auto &entries = entries_storage();
    auto match = std::ranges::find( entries, action_id, &entry::action_id );
    if( match == entries.end() ) {
        return false;
    }

    return run_entry( match->id );
}
} // namespace cata::lua_action_menu
