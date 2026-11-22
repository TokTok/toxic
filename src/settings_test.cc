#include "settings.h"

#include <gtest/gtest.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>

namespace {

Client_Config load_settings(const char *config_path)
{
    Client_Config settings;
    std::memset(&settings, 0, sizeof(settings));
    Run_Options run_opts;
    std::memset(&run_opts, 0, sizeof(run_opts));
    std::snprintf(run_opts.config_path, sizeof(run_opts.config_path), "%s", config_path);
    settings_load_main(&settings, &run_opts);
    return settings;
}

TEST(Settings, ExampleHasTheDefaults)
{
    const char *example = std::getenv("TOXIC_CONF_EXAMPLE");
    ASSERT_NE(example, nullptr);

    // Without a config file, toxic keeps its defaults.
    const Client_Config defaults = load_settings("");
    const Client_Config loaded = load_settings(example);
    EXPECT_EQ(std::memcmp(&defaults, &loaded, sizeof(defaults)), 0)
        << "misc/toxic.conf.example has a value that toxic doesn't use by default";
}

}  // namespace
