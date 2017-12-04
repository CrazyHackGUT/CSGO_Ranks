#if defined _csgoranks_included
  #endinput
#endif
#define _csgoranks_included

/******************************************************************************
 * CS:GO Competitive Ranks Enum
 ******************************************************************************/
enum CompetitiveGORank {
    NoRank,                         /**< Player don't have a Rank */

    SilverI,                        /**< The Silver I */
    SilverII,                       /**< The Silver II */
    SilverIII,                      /**< The Silver III */
    SilverIV,                       /**< The Silver IV */
    SilverElite,                    /**< The Silver Elite */
    SilverEliteMaster,              /**< The Silver Elite Master */

    GoldNovaI,                      /**< Gold Nova I */
    GoldNovaII,                     /**< Gold Nova II */
    GoldNovaIII,                    /**< Gold Nova III */
    GoldNovaMaster,                 /**< Gold Nova Master */

    MasterGuardianI,                /**< Master Guardian I */
    MasterGuardianII,               /**< Master Guardian II */
    MasterGuardianElite,            /**< Master Guardian Elite */
    MasterGuardianDistinguished,    /**< Distinguished Master Guardian */

    LegendaryEagle,                 /**< Legendary Eagle */
    LegendaryEagleMaster,           /**< Legendary Eagle Master */

    SupremeMasterFirstClass,        /**< Supreme Master First Class */

    GlobalElite                     /**< The Global Elite */
}

/******************************************************************************
 * Natives
 ******************************************************************************/

/**
 * Is it possible to change the ranks or not?
 *
 * @return      bool
 */
native bool IsCompetitiveRankWorking();

/**
 * Changes a player rank.
 *
 * @param       int                 Player entity ID.
 * @param       CompetitiveGORank   The new Rank.
 *
 * @return      void
 * @error       Competitive Ranks not working or Invalid player entity ID or Invalid new Rank.
 */
native void SetPlayerCompetitiveRank(int iClient, CompetitiveGORank eRank);

/**
 * Returns a player rank.
 *
 * @param       int                 Player entity ID.
 *
 * @return      CompetitiveGORank
 * @error       Competitive Ranks not working or Invalid player entity ID.
 */
native CompetitiveGORank GetPlayerCompetitiveRank(int iClient);

/******************************************************************************
 * Plugin Library
 ******************************************************************************/
public SharedPlugin __pl_csgoranks = {
    name        = "csgoranks",
    file        = "csgoranks.smx",
#if defined REQUIRE_PLUGIN
    required    = 1
#else
    required    = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_csgoranks_SetNTVOptional() {
    MarkNativeAsOptional("IsCompetitiveRankWorking");
    MarkNativeAsOptional("SetPlayerCompetitiveRank");
    MarkNativeAsOptional("GetPlayerCompetitiveRank");
}
#endif