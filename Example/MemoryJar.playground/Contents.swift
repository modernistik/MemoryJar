import UIKit
import MemoryJar

// use shared, or create your own with MemoryJar()
let cache = MemoryJar.shared

// Some API response
let json = "[1, 2, 3, 4]"
let cacheKey = "https://some.api/"

cache["company"] = "Modernistik"

print( cache["company"] ?? "none" )

// set the value
cache.set(value: json, forKey: cacheKey)

// get the value if it is not older than 1 day
if let result = cache.get(forKey: cacheKey, maxAge: 86400) {
    print(result)
}

// deletes all cache objects
cache.removeAllObjects()
