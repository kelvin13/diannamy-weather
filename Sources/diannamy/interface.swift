import GLFW
import OpenGL

enum PhysicalKey
{
case esc,
     tab,
     up,
     left,
     right,
     down,
     space

    init?(_ key_code:CInt)
    {
        switch key_code
        {
        case GLFW_KEY_ESCAPE:
            self = .esc
        case GLFW_KEY_TAB:
            self = .tab
        case GLFW_KEY_UP:
            self = .up
        case GLFW_KEY_LEFT:
            self = .left
        case GLFW_KEY_RIGHT:
            self = .right
        case GLFW_KEY_DOWN:
            self = .down
        case GLFW_KEY_SPACE:
            self = .space
        default:
            return nil
        }
    }
}

enum MouseButton
{
case left, middle, right

    init?(_ button_code:CInt)
    {
        switch button_code
        {
        case GLFW_MOUSE_BUTTON_LEFT:
            self = .left
        case GLFW_MOUSE_BUTTON_MIDDLE:
            self = .middle
        case GLFW_MOUSE_BUTTON_RIGHT:
            self = .right
        default:
            return nil
        }
    }
}

protocol GameScene
{
    //var frame:Size2D { get }
    func show3D(_:Double)
    mutating func on_resize(width:CInt, height:CInt)
    mutating func start_drag(button:MouseButton)
    mutating func drag(x:CInt, y:CInt, x0:CInt, y0:CInt)
    mutating func end_drag()
    mutating func scroll(axis:Bool, sign:Bool)
    mutating func key(_:PhysicalKey)

    func release_resources()
}

// use reference type because we want to attach `self` pointer to GLFW
final
class Interface
{
    private
    struct MouseAnchor
    {
        let x:CInt,
            y:CInt,
            button:MouseButton
    }

    private
    let window:OpaquePointer
    private
    var width :CInt,
        height:CInt,
        mouse_anchor:MouseAnchor?,
        scenes:[GameScene]

    init(width:CInt, height:CInt, name:String)
    {
        guard let window:OpaquePointer = glfwCreateWindow(width, height, name, nil, nil)
        else
        {
            fatalError("glfwCreateWindow failed")
        }

        glfwMakeContextCurrent(window)
        glfwSwapInterval(1)

        self.window = window
        self.width  = width
        self.height = height
        self.scenes = [View3D(frame_width: width, frame_height: height)]

        // attach pointer to self to window
        glfwSetWindowUserPointer(window, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))

        glfwSetFramebufferSizeCallback  (window, { Interface.resize_link(window: $0, width: $1, height: $2) })
        glfwSetKeyCallback              (window, { Interface.key_link   (window: $0, key_code: $1, scancode: $2, action: $3, mode: $4) })
        glfwSetCharCallback             (window, { Interface.char_link  (window: $0, codepoint: $1) })
        glfwSetCursorPosCallback        (window, { Interface.hover_link (window: $0, x: $1, y: $2) })
        glfwSetMouseButtonCallback      (window, { Interface.press_link (window: $0, button_code: $1, action: $2, mods: $3) })
        glfwSetScrollCallback           (window, { Interface.scroll_link(window: $0, x: $1, y: $2) })
    }

    deinit
    {
        for scene:GameScene in self.scenes
        {
            scene.release_resources()
        }
        glfwDestroyWindow(self.window)
    }

    func play()
    {
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
        glEnable(cap: GL_BLEND)
        glEnable(cap: GL_DEPTH_TEST)

        var t0:Double = glfwGetTime()
        while glfwWindowShouldClose(self.window) == 0
        {
            glfwPollEvents()
            glClearColor(0.15, 0.15, 0.15, 1)
            glClear(mask: GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

            let t1:Double = glfwGetTime()
            let dt:Double = t1 - t0
            for scene in self.scenes
            {
                scene.show3D(dt)
            }
            t0 = t1

            glfwSwapBuffers(self.window)
        }
    }

    fileprivate
    func resize_to(width h:CInt, height k:CInt)
    {
        self.width  = h
        self.height = k
        for i in self.scenes.indices
        {
            self.scenes[i].on_resize(width: h, height: k)
        }
    }

    private
    func scroll(axis:Bool, sign:Bool)
    {
        self.scenes[0].scroll(axis: axis, sign: sign)
    }

    private
    func hover(_ x:CInt, _ y:CInt)
    {
        if let mouse_anchor = self.mouse_anchor
        {
            self.scenes[0].drag(x: x, y: y, x0: mouse_anchor.x, y0: mouse_anchor.y)
        }
    }

    private
    func press(_ x:CInt, _ y:CInt, button:MouseButton)
    {
        self.mouse_anchor = MouseAnchor(x: x, y: y, button: button)
        self.scenes[0].start_drag(button: button)
    }

    private
    func release()
    {
        self.scenes[0].end_drag()
        self.mouse_anchor = nil
    }

    private
    func key(_ key:PhysicalKey)
    {
        self.scenes[0].key(key)
    }

    static
    func error_callback(error:CInt, description:UnsafePointer<CChar>?)
    {
        if let description = description
        {
            print("Error \(error): \(String(cString: description))")
        }
    }

    private static
    func reconstitute(from window:OpaquePointer?) -> Interface
    {
        return Unmanaged<Interface>.fromOpaque(glfwGetWindowUserPointer(window)).takeUnretainedValue()
    }

    private static
    func scroll_link(window:OpaquePointer?, x:Double, y:Double)
    {
        Interface.reconstitute(from: window).scroll(axis: y != 0, sign: (x + y) == 1)
    }

    private static
    func hover_link(window:OpaquePointer?, x:Double, y:Double)
    {
        Interface.reconstitute(from: window).hover(CInt(x), CInt(y))
    }

    private static
    func press_link(window:OpaquePointer?, button_code:CInt, action:CInt, mods:CInt)
    {
        let interface = Interface.reconstitute(from: window)
        if action == GLFW_PRESS
        {
            var x:Double = 0, y:Double = 0
            glfwGetCursorPos(window, &x, &y)

            guard let button:MouseButton = MouseButton(button_code)
            else
            {
                print("invalid mouse button \(button_code)")
                return
            }

            interface.press(CInt(x), CInt(y), button: button)
        }
        else // if action == GLFW_RELEASE
        {
            interface.release()
        }
    }

    private static
    func key_link(window:OpaquePointer?, key_code:CInt, scancode:CInt, action:CInt, mode:CInt)
    {
        guard action == GLFW_PRESS
        else
        {
            return
        }

        guard let key:PhysicalKey = PhysicalKey(key_code)
        else
        {
            print("invalid key \(key_code)")
            return
        }

        Interface.reconstitute(from: window).key(key)
    }

    private static
    func resize_link(window:OpaquePointer?, width h:CInt, height k:CInt)
    {
        glViewport(0, 0, h, k)
        Interface.reconstitute(from: window).resize_to(width: h, height: k)
    }

    private static
    func char_link(window:OpaquePointer?, codepoint:CUnsignedInt)
    {
        /*
        Interface.reconstitute(from: window)
        ._letter = Character(UnicodeScalar(codepoint) ?? "\u{0}")
        */
    }
}

/*
func read_gl_errors(hide:Bool = false)
{
    while true
    {
        let e = SGLOpenGL.glGetError()
        if e == SGLOpenGL.GL_NO_ERROR
        {
            break
        }
        else if !hide
        {
            print(String(e, radix: 16))
        }
    }
}
*/
