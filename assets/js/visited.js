function canUseVisitedFeature() {
  return !!localStorage;
}

function _getStorageName(trailName) {
  return 'has-visited-' + trailName;
}

function hasVisitedTrail(trailName) {
  return !!localStorage.getItem(_getStorageName(trailName));
}

function markTrailVisited(trailName, hasVisited) {
  if (hasVisited) {
    localStorage.setItem(_getStorageName(trailName), 'visited');
  } else {
    localStorage.removeItem(_getStorageName(trailName));
  }
}
