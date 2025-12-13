# Offline-First Architecture with Hive

## Overview

The app now uses **Hive** as a local database to provide true offline-first functionality. All data is stored locally and synced to Firebase when online.

## Architecture Components

### 1. **LocalStorageService** (`lib/services/local_storage_service.dart`)

- **Purpose**: Central service for all local data persistence
- **Storage**: Uses Hive boxes for courses, components, records, offline queue, and metadata
- **Features**:
  - Fast, efficient NoSQL storage
  - Survives app restarts
  - Type-safe with Hive adapters
  - Provides CRUD operations for all entities

### 2. **OfflineQueueService** (`lib/services/offline_queue_service.dart`)

- **Purpose**: Manages pending sync operations
- **Storage**: Now uses Hive instead of SharedPreferences
- **Features**:
  - Queues operations when offline
  - Auto-syncs when connection restored
  - Tracks failed operations for retry

### 3. **CourseAPI** (`lib/api/course_api.dart`)

- **Strategy**: Offline-first pattern
- **Flow**:
  1. **Always** save to local storage first
  2. If online → sync to Firebase immediately
  3. If offline → queue for later sync
  4. If sync fails → automatically queue for retry

### 4. **CourseProvider** (`lib/providers/course_provider.dart`)

- **Change**: Removed in-memory `_modifiedCourses` cache
- **Now uses**: LocalStorageService for persistent state
- **Benefit**: State survives app restarts

## Data Flow

### Creating/Updating Data

```
User Action
    ↓
Save to Local Storage (Hive) ✅ [Instant, Always Works]
    ↓
Check Connectivity
    ↓
Online? → Sync to Firebase
         → If fails: Queue for retry
    ↓
Offline? → Queue for later sync
```

### Reading Data

```
Request Data
    ↓
Read from Local Storage (Instant)
    ↓
If Online:
    ↓
    Try fetch from Firebase
    ↓
    Update local storage with fresh data
    ↓
If Offline or Fetch Fails:
    ↓
    Use local data (still available)
```

## Key Benefits

### ✅ True Offline Persistence

- All changes saved locally using Hive
- Data persists across app restarts
- No data loss when app closes

### ✅ Seamless Online Sync

- When connected, automatically syncs to Firebase
- Failed syncs are queued for retry
- User never waits for network

### ✅ Fast Performance

- Reads from local database are instant
- No network delays for UI updates
- Optimistic updates with background sync

### ✅ Clean Architecture

- Clear separation of concerns
- Single source of truth (LocalStorageService)
- Easy to test and maintain

## Storage Structure

### Hive Boxes

- **`courses`**: All user courses (Course objects)
- **`components`**: All course components (Component objects)
- **`records`**: All grade records (Records objects)
- **`offline_queue`**: Pending sync operations (Map)
- **`metadata`**: Sync timestamps and app metadata (Dynamic)

### Type IDs (for Hive adapters)

- `0`: Course
- `1`: Component
- `2`: Records
- `3`: GradingSystem
- `4`: GradeRange

## Usage Examples

### Saving a Course

```dart
// In CourseAPI
await _localStorage.saveCourse(course);  // Saved instantly to Hive
// Then sync to Firebase if online
```

### Loading Courses

```dart
// In CourseProvider
final localCourse = _localStorage.getCourse(courseId);  // Instant read
// Then refresh from Firebase if online
```

### Checking Storage Stats

```dart
final stats = _localStorage.getStorageStats();
print('Courses: ${stats['courses']}');
print('Components: ${stats['components']}');
```

## Migration Notes

### Before (Problems)

- ❌ In-memory cache lost on app restart
- ❌ Offline changes disappeared when app closed
- ❌ Firebase cache unreliable for writes
- ❌ Split logic between SharedPreferences and memory

### After (Solutions)

- ✅ Persistent Hive storage survives restarts
- ✅ All offline changes preserved
- ✅ Single source of truth
- ✅ Clean, maintainable architecture

## Monitoring

### App Startup

Watch console for initialization summary:

```
═══════════════════════════════════════
🚀 GradesKo App Initialized
═══════════════════════════════════════
📡 Connectivity: Online ✅
📦 Local Storage Stats:
   • Courses: 5
   • Components: 12
   • Records: 48
   • Queued Operations: 2
═══════════════════════════════════════
```

### Sync Operations

- `💾` = Saved to local storage
- `✅` = Synced to Firebase
- `📴` = Queued for offline sync
- `⚠️` = Sync failed, will retry

## Testing Offline Mode

1. **Airplane Mode**: Turn on airplane mode, use app normally
2. **Close App**: Close and reopen - data should persist
3. **Go Online**: Turn off airplane mode - watch auto-sync
4. **Check Console**: See sync operations in logs

## Future Enhancements

- [ ] Add conflict resolution for offline edits
- [ ] Implement data compression for large datasets
- [ ] Add encryption for sensitive data
- [ ] Implement selective sync (only changed data)
- [ ] Add storage quota management
- [ ] Background sync service for iOS/Android

## Troubleshooting

### Clear All Local Data

```dart
await LocalStorageService().clearAllData();
```

### Check Last Sync Time

```dart
final lastSync = _localStorage.getLastFirebaseSync();
print('Last synced: $lastSync');
```

### View Pending Operations

```dart
final pending = _localStorage.queuedOperationsCount;
print('Pending syncs: $pending');
```

---

**Note**: This architecture ensures your app works perfectly offline while maintaining seamless Firebase sync when online. All data is preserved across app restarts.
