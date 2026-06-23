# Changelog

## build 1-3 (mar 30-apr 2)
- inital screens built (groups, camera, library, profile - basic)
- group code is copy-able
- users can feature 9 photos on their profile
- lambda/eventbridge done
- camera buttons simplified 
- cover photo and photo grid for groups done
- notification attempt via APNs


## build 4 (jun 18-19)
- google sign in button fixed
- search feature
- followers/following lists
- delete only photos from groups that you took
- remove any photos from library
- fixed camera and orientation issues
- users can update their bio
- unlock icon and "unlocked on ___" when a group is unlocked
- date and time added to each group 

## build 5 (jun 21)
- group edit permissions — anyone can edit group name and photo
- owners can only delete groups, members can only leave groups
- owners can change unlock times
- push notifications -> FCM
  - group unlocked
  - someone joins group
- privacy policy added

## build 6 (jun 22-#)
- click to view profile picture
- sign in with apple (SIWA)
- library-only photos for the 9 featured photos
- tap to enlarge profile pics
- deployment target lowered to iOS 17.6
- settings rearranged

- notifications fixed (hopefully)
- onboarding screens (6-card carousel)
- help button (groups screen + settings)
- deep links / invite links
  - navigates straight to group (handles logged out / no account / app not installed / already a member)
- share invite screen after creating a group
- in-group invite UI — copy link / share button (replaced the code pill)
- users can join via link or invite code; both copyable and usable to join
- long-press a group → preview (cover + name) with share / copy invite
- terms & conditions + privacy policy (in-app + website)
- og meta tag for imessage preview (PENDING — logo + copy ready, needs /join page routing)
- fixed push notifications not registering for new users (FCM token race condition: token fired before auth completed, so fresh accounts never saved a device token)
- added notification on/off toggle in settings → more (token-based; deletes/re-registers device token, deep-links to iOS Settings if permission denied)
- fixed photo orientation: landscape photos now capture and display correctly (camera now reads device orientation at capture time instead of forcing portrait)
- migrated landing site GitHub Pages → Netlify so /join/* serves with a 200 status, enabling iMessage link previews (OG card) and a TestFlight invite landing page
- added "add members" to groups: search any user and add them directly, they get a notification and tapping it opens the group
- added an "add friends" button to the post-create share screen for adding people right after making a group
- fixed notification taps not opening the group when the app was on another tab (affected unlock, member-joined, and add-member notifications)

## build 7
- ...