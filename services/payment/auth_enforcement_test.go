package main

import (
	"context"
	"testing"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	pb "quiz-battle/proto"
)

// TestPaymentServiceEnforcement_RejectsUnauthenticated proves every
// payment RPC rejects callers without a JWT. The unary interceptor
// is registered in main.go with no skip methods, but money flows
// through this service — defense-in-depth in each handler matters
// more here than anywhere else in the codebase.
func TestPaymentServiceEnforcement_RejectsUnauthenticated(t *testing.T) {
	srv, _, _ := newTestPaymentServer(t)
	ctx := context.Background() // no JWT

	cases := []struct {
		method string
		call   func() error
	}{
		{"CreateOrder", func() error {
			_, err := srv.CreateOrder(ctx, &pb.CreateOrderRequest{PlanDuration: "monthly"})
			return err
		}},
		{"VerifyPayment", func() error {
			_, err := srv.VerifyPayment(ctx, &pb.VerifyPaymentRequest{
				RazorpayOrderId:   "x",
				RazorpayPaymentId: "y",
				RazorpaySignature: "z",
			})
			return err
		}},
		{"GetPlanStatus", func() error {
			_, err := srv.GetPlanStatus(ctx, &pb.GetPlanStatusRequest{})
			return err
		}},
		{"GetPaymentHistory", func() error {
			_, err := srv.GetPaymentHistory(ctx, &pb.GetPaymentHistoryRequest{})
			return err
		}},
	}
	for _, tc := range cases {
		t.Run(tc.method, func(t *testing.T) {
			err := tc.call()
			if status.Code(err) != codes.Unauthenticated {
				t.Errorf("%s without JWT: got code=%v err=%v, want Unauthenticated",
					tc.method, status.Code(err), err)
			}
		})
	}
}
