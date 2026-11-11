class ApiError(Exception):
    """Error controlado de la API: lleva un mensaje claro y un código HTTP."""

    def __init__(self, mensaje, status=400):
        super().__init__(mensaje)
        self.mensaje = mensaje
        self.status = status
