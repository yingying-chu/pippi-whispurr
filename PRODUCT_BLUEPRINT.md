# PiPi Product Blueprint

## Product vision

PiPi helps people preserve the story of each pet's life. It brings together photos, memories, milestones, and personal writing into a private timeline that can grow from adoption through every stage of life.

PiPi is not primarily a photo scanner or calendar. Those are supporting tools. The product's central object is a pet's living story.

## Core promise

**Tell the story of a pet's whole life.**

PiPi should help a person answer:

- What was my pet like during each stage of life?
- Which moments do I never want to forget?
- How has our life together changed over time?
- Can I turn scattered photos into a story worth keeping?

## Product principles

1. **The pet comes first.** Every photo, entry, and milestone belongs within one or more pet stories.
2. **Writing should feel easy.** A memory can begin with one sentence, one photo, or a prompt.
3. **Automation assists; the owner decides.** PiPi can suggest pet matches and moments, but the user confirms identity and meaning.
4. **Private by default.** Personal photos and journals stay on-device unless the user deliberately shares or syncs them.
5. **The product becomes more valuable over time.** Returning to add small memories should gradually create a rich biography.
6. **Multiple pets are first-class.** The model must support separate stories, shared moments, and pets who look similar.

## Core product model

### Pet

The main organizing object.

- Name
- Profile and cover photos
- Species and optional breed
- Birthday, adoption day, or approximate age
- Pronouns (optional)
- Story status: current, remembered, or memorial
- Short introduction or personality description

### Memory

A journal entry representing a meaningful moment.

- Title (optional)
- Written story
- Date or date range
- One or more photos
- One or more pets
- Location (optional)
- Mood or theme (optional)
- Prompts used (optional)

A memory may belong to multiple pets. This is important for households where pets grow up together.

### Photo

A reference to an item in the person's photo library.

- Photo-library identifier
- Capture date
- Assigned pets
- Suggested pets and confidence
- Favorite status
- Caption (optional)
- Included memories

A photo may exist in a pet timeline without being part of a written memory.

### Milestone

A structured life event that appears on a pet's timeline.

- Milestone type
- Date or approximate date
- Note
- Photos
- Pet

Examples include adoption, first day home, birthday, first trip, training achievement, moving home, recovery, and remembrance.

## Primary user journey

### 1. Welcome

PiPi explains its promise in one sentence: preserve the story of every pet's life. It also explains that photo analysis is private and that the owner remains in control.

### 2. Create the first pet

The user adds a name and profile photo. All other profile fields are optional so setup never feels like paperwork.

### 3. Find photos

The user grants photo access. PiPi scans recent photos and suggests photos that may contain the pet.

For the first product version, the user manually assigns suggested pet photos. Later, confirmed examples can improve matching for that particular pet.

### 4. Review suggestions

A lightweight inbox presents uncertain photos with three fast actions:

- This is my pet
- Another pet
- Not a pet photo

The user should be able to review suggestions in batches rather than opening every photo.

### 5. Discover the pet timeline

Confirmed photos appear chronologically. Milestones and written memories are visually more prominent than ordinary photos.

### 6. Capture a memory

From any photo, date, or pet timeline, the user can write a short memory. PiPi may offer prompts such as:

- What do you remember most about this day?
- What was your pet learning at this age?
- What small habit made you smile?
- Who was there?

Prompts should help the user begin, never make journaling feel mandatory.

### 7. Revisit and shape the story

PiPi periodically surfaces earlier moments and incomplete memories. Over time, the user can view chapters such as the first year, favorite adventures, or life by home and season.

## Information architecture

The first release should have four primary destinations:

### Home

- Continue the latest memory
- Recent moments across all pets
- Photo suggestions awaiting review
- Gentle journaling prompt
- Upcoming or recent milestones

### Pets

- All pet profiles
- Add a pet
- Open a pet's profile and timeline

### Library

- All confirmed pet photos
- Calendar and grid browsing
- Filters by pet, date, favorite, and unassigned status
- Review suggestions

### Journal

- All written memories
- Drafts
- Search
- Create a new memory

Settings can live outside the primary navigation.

## Pet profile experience

Each pet profile should include:

- Cover and identity
- A short introduction
- Age or life dates
- Timeline
- Memories
- Milestones
- Photo collection
- Story summary or chapters later

The default profile view should be the timeline because it combines passive photo organization with active storytelling.

## Timeline behavior

The timeline contains three levels of content:

1. **Memories:** authored stories with photos; highest prominence.
2. **Milestones:** important structured events; medium prominence.
3. **Photo moments:** ordinary confirmed photos grouped by day or period; lowest prominence.

This prevents thousands of photos from overwhelming the meaningful story.

## Important edge cases

- A photo can contain several pets.
- Two pets may look nearly identical.
- A pet may have very few early photos.
- Dates may be approximate, especially for adoption history.
- Photo-library access may be limited or later revoked.
- A referenced photo may be deleted from the system library.
- A user may want a memorial story for a pet who has died.
- A family member may have photos unavailable on the current device.

The interface should communicate uncertainty honestly and make corrections easy.

## MVP: first complete product loop

The first milestone is complete when a user can:

1. Create multiple pet profiles.
2. Scan or choose photos from the device library.
3. Assign each photo to one or more pets.
4. Open a chronological timeline for a pet.
5. Create, edit, and delete a written memory with photos.
6. Add a milestone.
7. Close and reopen the app without losing profiles, assignments, or writing.

### Included

- Local persistence
- Pet profiles
- Multi-pet photo assignment
- Per-pet timelines
- Journal entries
- Milestones
- Existing calendar, filters, and favorites where useful

### Deferred

- Automatic recognition of a specific individual pet
- Generated long-form narratives
- Family collaboration
- Cloud sync
- Printed books
- Social feeds
- Public profiles

These features should wait until the private capture-and-revisit loop feels valuable by itself.

## Recommended build sequence

### Phase 1: durable foundation

- Introduce persistent models for pets, memories, milestones, and photo assignments.
- Preserve scanned photo references across launches.
- Separate library scanning from story data.

### Phase 2: pet identity

- Add pet creation and editing.
- Add a pet switcher and pet profile.
- Support assigning a photo to multiple pets.

### Phase 3: storytelling

- Add the pet timeline.
- Add memory creation and editing.
- Add milestones and gentle writing prompts.

### Phase 4: assisted organization

- Add a photo-review inbox.
- Use confirmed photos to suggest likely pet assignments.
- Add resurfacing prompts for unrecorded periods.

### Phase 5: visual redesign

- Establish the emotional tone and visual system.
- Redesign navigation and hierarchy around pet stories.
- Add motion, empty states, and polished memory presentation.

## Product success signals

Early success should measure story creation rather than scan volume:

- The user creates at least one pet profile.
- The user assigns photos to that pet.
- The user writes the first memory.
- The user returns and adds another memory later.
- The user revisits an older memory.

The clearest sign of product value is not "photos detected." It is "a story now exists that did not exist before."

## Next implementation decision

Use a persistent local data layer as the foundation. The current `PetPhoto` model is tied directly to `PHAsset`, so scan results and pet assignments cannot safely function as durable story records. The next engineering step should establish persistent pet, memory, milestone, and photo-reference models before adding new screens.
