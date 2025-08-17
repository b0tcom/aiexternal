"""
PID controller implementation.

The PIDController class computes a control signal based on the difference
between a desired target and the current measurement.  It integrates the
error over time and differentiates the error to reduce overshoot and
oscillations.  Use separate instances for horizontal and vertical
corrections.
"""

from typing import Optional


class PIDController:
    """A simple discrete PID controller."""

    def __init__(
        self,
        kp: float,
        ki: float,
        kd: float,
        dt: float = 1.0 / 60.0,
        max_output: Optional[float] = None,
        integral_limit: Optional[float] = None,
    ) -> None:
        self.kp = kp
        self.ki = ki
        self.kd = kd
        self.dt = dt
        self.max_output = max_output
        self.integral_limit = integral_limit
        self.integral = 0.0
        self.prev_error = 0.0

    def reset(self) -> None:
        """Reset the integral and derivative state."""
        self.integral = 0.0
        self.prev_error = 0.0

    def update(self, error: float) -> float:
        """Compute the control output for the given error."""
        # Integral term
        self.integral += error * self.dt
        if self.integral_limit is not None:
            self.integral = max(min(self.integral, self.integral_limit), -self.integral_limit)
        # Derivative term
        derivative = (error - self.prev_error) / self.dt
        # PID output
        output = self.kp * error + self.ki * self.integral + self.kd * derivative
        self.prev_error = error
        # Clamp output if a max value is provided
        if self.max_output is not None:
            output = max(min(output, self.max_output), -self.max_output)
        return output