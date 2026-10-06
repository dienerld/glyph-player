# Product

<!-- impeccable:product-schema 1 -->

## Platform

desktop (Flutter, Linux + Windows). Not one of web/ios/android/adaptive; no native-mobile references apply.

## Stack

Flutter stable, media_kit (libmpv), SQLite, Riverpod. Chosen with the user (see docs/superpowers/specs/2026-10-06-live-tv-design.md).

## Users

One person (the owner), at a PC with mouse and keyboard, watching live TV from a personal IPTV M3U_plus list. Confirmed by the user: PC, mouse + keyboard.

## Product Purpose

Replace Hypnotix. Browse and watch live channels from a 50 MB+ local playlist (~220k entries, 3.3k live) without the app freezing during list updates. Later: movies, series grouped by distributor, history, auto-advance.

## Capabilities and Constraints

Live only in v1. Local data only, no EPG, no remote APIs besides the playlist URL. Embedded mpv playback. Categories come from group-title.

## Evidence on Hand

Real playlist in the repo root (git-ignored). Channel logos are remote image URLs of uneven quality (imgur, wikimedia, tmdb); some entries have none. No EPG, no program art.

## Product Principles

- Speed beats ornament: the library must feel instant at 200k entries.
- Zapping is the core loop: reach any channel in two keystrokes.
- Never block the user on a background update.
- Honest empty and error states over blank screens.
