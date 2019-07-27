# MemoryJar

[![CI Status](https://img.shields.io/travis/modernistik/MemoryJar.svg?style=flat)](https://travis-ci.org/modernistik/MemoryJar)
[![Version](https://img.shields.io/cocoapods/v/MemoryJar.svg?style=flat)](https://cocoapods.org/pods/MemoryJar)
[![License](https://img.shields.io/cocoapods/l/MemoryJar.svg?style=flat)](https://cocoapods.org/pods/MemoryJar)
[![Platform](https://img.shields.io/cocoapods/p/MemoryJar.svg?style=flat)](https://cocoapods.org/pods/MemoryJar)

MemoryJar is a fast and efficient and thread-safe persistent string caching library that includes capacity management (LRU) and support for age expiration. It utilizes both in-memory and disk storage, supporting asynchronous writes for speed. This library was inspired by the caching mechanism on the Parse iOS SDK. 

This caching library is most useful when building a caching system for managing a REST API. 

## Usage

```swift
import MemoryJar

// use shared, or create your own with MemoryJar()
let cache = MemoryJar.shared

// Simple
cache["company"] = "Modernistik" 
// retrieve (no expiration)
let company = cache["company"] 

// Some API response
let json = """
{
    "name" : "Anthony Persaud",
    "id" : 7,
    "company" : {
        "name" : "Modernistik",
        "location": "San Diego, CA"
     }
}
"""

let cacheKey = "https://some.api/?id=7"

// set the value
cache.set(value: json, forKey: cacheKey)

// fetch value only if it is not older than 1 day.
if let result = cache.get(forKey: cacheKey, maxAge: 86400) {
    print(result)
}

// deletes all cache objects
cache.removeAllObjects()
```

## Installation

To install it, simply add the following line to your Podfile:

```ruby
pod "MemoryJar"
```

## License

MemoryJar is available under the MIT license. See the LICENSE file for more info.
