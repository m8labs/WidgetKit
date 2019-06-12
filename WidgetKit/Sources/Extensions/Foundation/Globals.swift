//
// Globals.swift
//
// WidgetKit, Copyright (c) 2018 M8 Labs (http://m8labs.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation

public func afterTimeout(_ seconds: Double, _ block: @escaping () -> Swift.Void) {
    if seconds <= 0 {
        block()
    } else {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            block()
        }
    }
}

public func asyncMain(_ block: @escaping () -> Swift.Void) {
    DispatchQueue.main.async {
        block()
    }
}

public func asyncGlobal(_ block: @escaping () -> Swift.Void) {
    DispatchQueue.global(qos: .utility).async {
        block()
    }
}

public func async(_ block: @escaping () -> Swift.Void) {
    asyncMain(block)
}

public func after(_ seconds: Double, _ block: @escaping () -> Swift.Void) {
    afterTimeout(seconds, block)
}
