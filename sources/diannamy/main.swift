import GLFW

func main()
{
    guard glfwInit() == 1
    else
    {
        fatalError("glfwInit() failed")
    }
    defer { glfwTerminate() }

    glfwSetErrorCallback{ Interface.error_callback(error: $0, description: $1) }

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3)
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3)
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_ANY_PROFILE)
    glfwWindowHint(GLFW_RESIZABLE, 1)
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, 1)

    let interface:Interface = Interface(width: 1200, height: 600, name: "Diannamy 3")

    interface.play()
}

main()
