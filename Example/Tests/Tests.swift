import XCTest
import MemoryJar

class Tests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        
        let cache = MemoryJar()
        let api = "https://www.modernistik.com".sha1
        let json = """
        {
            "name" : "John Appleseed",
            "id" : 7,
            "favorite_toy" : {
                "name" : "Teddy Bear"
            }
        }
"""

        cache.set(value: json, forKey: api)
        XCTAssert(true, "Pass")
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure() {
            // Put the code you want to measure the time of here.
        }
    }
    
}
